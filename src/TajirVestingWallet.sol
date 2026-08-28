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
 * @dev Extends VestingWalletCliff to provide cliff-based vesting functionality with linear unlock
 *
 * Features:
 * - Cliff period: No tokens unlock until cliff timestamp is reached
 * - Tranche-based vesting: After cliff, tokens unlock in N equal installments
 * - Minimalist: All schedule calculations (durations, intervals) are defined at deployment
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
        // As this is a one-and-done contract so that's why single revoke globally
        bool revoked;
        // Distinct upgrade authority — keeping revoke and upgrade under
        // different keys removes the single point of failure where one
        // compromised admin can both rug the unvested portion AND swap in
        // a malicious implementation.
        address upgrader;
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
        revert("TajirVestingWallet: use the 8-argument initialize.");
    }

    /**
     * @notice Initializes the minimalist tranche-based vesting wallet
     * @param beneficiary Address that will receive vested tokens
     * @param startTimestamp When vesting schedule begins (Mainnet launch)
     * @param durationSeconds Total duration from start to 100% unlock (Cliff + Vesting period)
     * @param cliffSeconds Duration of the cliff (zero tokens released)
     * @param trancheDuration_ Duration of a single installment in seconds (e.g., 30 days or 60 days)
     * @param totalTranches_ Total number of equal installments to be released
     * @param admin_ Address of the admin who can withdraw unvested tokens
     * @param upgrader_ Address allowed to authorize implementation upgrades.
     *                  Pass the same address as admin_ if a single key is desired,
     *                  but a separate timelock/governance key is recommended.
     */
    function initialize(
        address beneficiary,
        uint64 startTimestamp,
        uint64 durationSeconds,
        uint64 cliffSeconds,
        uint64 trancheDuration_,
        uint64 totalTranches_,
        address admin_,
        address upgrader_
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

        __VestingWallet_init(beneficiary, startTimestamp, durationSeconds);
        __VestingWalletCliff_init(cliffSeconds);

        TajirVestingWalletStorage storage $ = _getTajirVestingWalletStorage();
        $.trancheDuration = trancheDuration_;
        $.totalTranches = totalTranches_;
        $.admin = admin_;
        $.upgrader = upgrader_;
    }

    /**
     * @notice Allows the super_owner to withdraw any amount that hasn't vested yet.
     * @dev Claimable tokens (vested but not released) stay in the contract.
     * @param token The address of the token to withdraw. Use address(0) for Ether.
     * @param to The address to withdraw the tokens to.
     */
    function withdrawUnreleased(address token, address payable to) external {
        TajirVestingWalletStorage storage $ = _getTajirVestingWalletStorage();
        if ($.revoked) revert AlreadyRevoked();
        if (msg.sender != $.admin) revert NotAdmin();
        if (to == address(0)) revert ZeroAddress();

        bool native = token == address(0);

        uint256 currentBalance = native
            ? address(this).balance
            : IERC20(token).balanceOf(address(this));
        uint256 claimable = native ? releasable() : releasable(token);

        if (currentBalance <= claimable) revert NothingToWithdraw();

        uint256 withdrawable = currentBalance - claimable;

        $.revoked = true;

        emit VestingRevoked(token, withdrawable);

        if (native) Address.sendValue(to, withdrawable);
        else SafeERC20.safeTransfer(IERC20(token), to, withdrawable);
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
     * @dev Implements tranche-based schedule.
     * Calculates the number of full tranches passed since the cliff.
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
