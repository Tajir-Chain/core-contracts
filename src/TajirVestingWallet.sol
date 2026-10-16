// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {VestingWalletUpgradeable} from "@openzeppelin/contracts-upgradeable/finance/VestingWalletUpgradeable.sol";
import {VestingWalletCliffUpgradeable} from "@openzeppelin/contracts-upgradeable/finance/VestingWalletCliffUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title TajirVestingWallet
 * @notice Concrete implementation of OpenZeppelin VestingWalletCliff for TJR token distribution
 * @dev Extends VestingWalletCliff with a discrete, tranche-based unlock. Value does not
 *      accrue continuously — it steps at each tranche boundary.
 *
 * Features:
 * - Cliff period: No tokens unlock until cliff timestamp is reached
 * - Tranche-based vesting: After cliff, tokens unlock in N equal installments
 * - Minimalist: All schedule calculations (durations, intervals) are defined at deployment
 * - Single asset: each wallet vests exactly one asset, fixed at initialization. Anything
 *   else the wallet receives sits outside the schedule permanently — it is neither
 *   vested to the beneficiary nor withdrawable, and cannot affect the schedule.
 *
 * DO NOT SEND ANY OTHER ASSET HERE — it is permanently lost. Deliberate: an
 * admin exit would move the real allocation on a misconfigured wallet.
 *
 * @author TajirToken Chain Development Team
 */
contract TajirVestingWallet is UUPSUpgradeable, VestingWalletCliffUpgradeable {
    /**
     * @dev ERC-7201 namespaced storage layout for TajirVestingWallet
     * @custom:storage-location erc7201:tajir.storage.TajirVestingWallet
     *
     * This storage struct contains custom state variables for TajirVestingWallet.
     */
    struct TajirVestingWalletStorage {
        address admin;
        uint64 trancheDuration;
        uint64 totalTranches;
        // Revocation is terminal and applies to `vestedAsset` only. Every other
        // asset sits outside the schedule entirely, so the single flag can never
        // accelerate a schedule it was not meant to touch.
        bool revoked;
        // Distinct upgrade authority — keeping revoke and upgrade under
        // different keys removes the single point of failure where one
        // compromised admin can both rug the unvested portion AND swap in
        // a malicious implementation.
        address upgrader;
        // The one asset this wallet vests. address(0) means the chain's native
        // coin (TJR on Tajir chain, ETH on Ethereum). Fixed at initialization.
        address vestedAsset;
    }

    // keccak256(abi.encode(uint256(keccak256("tajir.storage.TajirVestingWallet")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant TajirVestingWalletStorageLocation =
        0x6b3ee920f8f5ddbcab31f463576c049ff8ab9b61bb8785a578e6dc5c90bb9900;

    /*
     * ERRORS
     */
    error NotAdmin();
    error NotUpgrader();
    error ZeroAddress();
    error NothingToWithdraw();
    error ZeroTrancheDuration();
    error ZeroTotalTranches();
    error InvalidScheduleParams();
    error AlreadyRevoked();
    error NotVestedAsset();
    error ScheduleLocksNothing();
    error NoBalanceMoved();
    error OwnershipLocked();

    /*
     * EVENTS
     */
    event VestingRevoked(address indexed token, uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Prevents calling the inherited 3-argument initialize method
    function initialize(address, uint64, uint64) public pure override {
        revert("TajirVestingWallet: use the 9-argument initialize.");
    }

    /**
     * @notice Initializes the minimalist tranche-based vesting wallet
     * @param beneficiary Address that will receive vested tokens
     * @param startTimestamp When vesting schedule begins (Mainnet launch)
     * @param durationSeconds Total duration from start to 100% unlock (Cliff + Vesting period)
     * @param cliffSeconds Duration of the cliff (zero tokens released)
     * @param trancheDuration_ Duration of a single installment in seconds (e.g., 30 days or 60 days)
     * @param totalTranches_ Total number of equal installments to be released
     * @param admin_ Address of the admin who can revoke the vesting
     * @param upgrader_ Address allowed to authorize implementation upgrades.
     *                  Pass the same address as admin_ if a single key is desired,
     *                  but a separate timelock/governance key is recommended.
     * @param vestedAsset_ The single asset this wallet vests. Pass address(0) for
     *                     the chain's native coin, or the ERC-20 address otherwise.
     *                     Every other asset the wallet receives is permanently outside
     *                     the schedule and cannot be withdrawn.
     */
    function initialize(
        address beneficiary,
        uint64 startTimestamp,
        uint64 durationSeconds,
        uint64 cliffSeconds,
        uint64 trancheDuration_,
        uint64 totalTranches_,
        address admin_,
        address upgrader_,
        address vestedAsset_
    ) external initializer {
        if (admin_ == address(0)) revert ZeroAddress();
        if (upgrader_ == address(0)) revert ZeroAddress();
        if (trancheDuration_ == 0) revert ZeroTrancheDuration();
        if (totalTranches_ == 0) revert ZeroTotalTranches();
        if (
            (totalTranches_ * trancheDuration_) + cliffSeconds !=
            durationSeconds
        ) {
            revert InvalidScheduleParams();
        }
        // A back-dated start is intentional, but the schedule must still lock
        // value at this moment or the wallet is fully vested on deployment.
        if (
            uint256(startTimestamp) + uint256(durationSeconds) <=
            block.timestamp
        ) {
            revert ScheduleLocksNothing();
        }

        __VestingWallet_init(beneficiary, startTimestamp, durationSeconds);
        __VestingWalletCliff_init(cliffSeconds);

        TajirVestingWalletStorage storage $ = _getTajirVestingWalletStorage();
        $.trancheDuration = trancheDuration_;
        $.totalTranches = totalTranches_;
        $.admin = admin_;
        $.upgrader = upgrader_;
        $.vestedAsset = vestedAsset_;
    }

    /**
     * @notice Revokes the vesting and returns the not-yet-vested portion to `to`.
     * @dev Claimable tokens (vested but not released) stay in the contract.
     *      `token` must be `vestedAsset`; no other asset may latch the revocation
     *      flag. Terminal: one call per wallet.
     * @param token Must equal `vestedAsset`. address(0) when the vested asset is native.
     * @param to The address to return the unvested portion to.
     */
    function withdrawUnreleased(address token, address payable to) external {
        TajirVestingWalletStorage storage $ = _getTajirVestingWalletStorage();
        if (msg.sender != $.admin) revert NotAdmin();
        if ($.revoked) revert AlreadyRevoked();
        if (to == address(0)) revert ZeroAddress();
        if (token != $.vestedAsset) revert NotVestedAsset();

        bool native = token == address(0);

        uint256 balanceBefore = native
            ? address(this).balance
            : IERC20(token).balanceOf(address(this));
        uint256 claimable = native ? releasable() : releasable(token);

        if (balanceBefore <= claimable) revert NothingToWithdraw();

        uint256 withdrawable = balanceBefore - claimable;

        $.revoked = true;

        if (native) Address.sendValue(to, withdrawable);
        else SafeERC20.safeTransfer(IERC20(token), to, withdrawable);

        uint256 balanceAfter = native
            ? address(this).balance
            : IERC20(token).balanceOf(address(this));
        if (balanceAfter >= balanceBefore) revert NoBalanceMoved();

        // Report what actually left, not what was intended. A non-conserving
        // asset can move less than `withdrawable`; latching the flag on an
        // unverified number is what let a no-op transfer revoke for free.
        emit VestingRevoked(token, balanceBefore - balanceAfter);
    }

    /**
     * @notice Ownership of a vesting wallet is fixed at initialization.
     * @dev owner() is the beneficiary and every release() pays it. Renouncing would
     *      burn the allocation to address(0); transferring would sell the live
     *      position in one unrestricted call. Neither has a legitimate use here.
     */
    function renounceOwnership() public pure override {
        revert OwnershipLocked();
    }

    /// @dev See {renounceOwnership}.
    function transferOwnership(address) public pure override {
        revert OwnershipLocked();
    }

    /**
     * @notice Returns whether the vesting has been revoked
     */
    function hasRevoked() external view returns (bool) {
        return _getTajirVestingWalletStorage().revoked;
    }

    /**
     * @notice Returns the duration of a single tranche in seconds
     */
    function trancheDuration() external view returns (uint64) {
        return _getTajirVestingWalletStorage().trancheDuration;
    }

    /**
     * @notice Returns the total number of tranches
     */
    function totalTranches() external view returns (uint64) {
        return _getTajirVestingWalletStorage().totalTranches;
    }

    /**
     * @notice Returns the address allowed to authorize upgrades.
     */
    function upgrader() external view returns (address) {
        return _getTajirVestingWalletStorage().upgrader;
    }

    /**
     * @notice Returns the single asset this wallet vests (address(0) = native).
     */
    function vestedAsset() external view returns (address) {
        return _getTajirVestingWalletStorage().vestedAsset;
    }

    /**
     * @notice Native amount vested at `timestamp`.
     * @dev Returns `released()` when the vested asset is an ERC-20, so native
     *      holdings are outside the schedule entirely and `releasable()` is zero.
     *      Clamped to `released()` so a shrinking balance degrades gracefully
     *      instead of underflowing in the inherited `releasable()`.
     */
    function vestedAmount(
        uint64 timestamp
    ) public view virtual override returns (uint256) {
        uint256 alreadyReleased = released();
        if (_getTajirVestingWalletStorage().vestedAsset != address(0)) {
            return alreadyReleased;
        }
        uint256 vested = super.vestedAmount(timestamp);
        return vested < alreadyReleased ? alreadyReleased : vested;
    }

    /**
     * @notice ERC-20 amount vested at `timestamp`.
     * @dev Returns `released(token)` for every asset other than `vestedAsset`, so
     *      revoking or holding another token can never move this schedule. address(0)
     *      is rejected here even when it IS the vested asset — the native coin belongs
     *      to the overload above, and reaching `super` with it would call `balanceOf`
     *      on the zero address. Clamped for the same reason as the native overload.
     */
    function vestedAmount(
        address token,
        uint64 timestamp
    ) public view virtual override returns (uint256) {
        uint256 alreadyReleased = released(token);
        TajirVestingWalletStorage storage $ = _getTajirVestingWalletStorage();
        if (token == address(0) || token != $.vestedAsset) {
            return alreadyReleased;
        }
        uint256 vested = super.vestedAmount(token, timestamp);
        return vested < alreadyReleased ? alreadyReleased : vested;
    }

    /**
     * @dev Implements tranche-based schedule.
     * Calculates the number of full tranches passed since the cliff.
     * Only ever reached for `vestedAsset` — the `vestedAmount` overrides above
     * short-circuit every other asset — so the terminal `revoked` branch cannot
     * accelerate a schedule other than this wallet's own.
     */
    function _vestingSchedule(
        uint256 totalAllocation,
        uint64 timestamp
    ) internal view override returns (uint256) {
        TajirVestingWalletStorage storage $ = _getTajirVestingWalletStorage();
        if (timestamp < cliff()) {
            return 0;
        } else if ($.revoked || timestamp >= end()) {
            return totalAllocation;
        } else {
            uint256 tranchesPassed = (timestamp - cliff()) / $.trancheDuration;
            return (totalAllocation * tranchesPassed) / $.totalTranches;
        }
    }

    /**
     * @notice Returns the storage struct at the ERC-7201 namespaced location
     * @return $ The storage struct
     */
    function _getTajirVestingWalletStorage()
        private
        pure
        returns (TajirVestingWalletStorage storage $)
    {
        assembly {
            $.slot := TajirVestingWalletStorageLocation
        }
    }

    /**
     * @notice Authorize the upgrade of the contract
     * @dev Only the upgrader can authorize an upgrade. Decoupled from `admin`
     *      so a single compromised key cannot both revoke AND swap impls.
     */
    function _authorizeUpgrade(
        address /* newImplementation */
    ) internal virtual override {
        if (msg.sender != _getTajirVestingWalletStorage().upgrader) {
            revert NotUpgrader();
        }
    }
}
