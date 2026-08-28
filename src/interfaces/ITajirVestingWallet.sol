// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/// @title ITajirVestingWallet
/// @notice Interface for the TajirVestingWallet cliff-and-tranche ERC-20 vesting contract
/// @dev Covers initialization, release, admin withdrawal, revocation, and UUPS upgrade surface
interface ITajirVestingWallet {
    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    /// @notice Thrown when a caller is not the designated admin
    error NotAdmin();

    /// @notice Thrown when a caller is not the designated upgrader
    error NotUpgrader();

    /// @notice Thrown when a zero address is provided where a non-zero address is required
    error ZeroAddress();

    /// @notice Thrown when the withdrawable balance is zero
    error NothingToWithdraw();

    /// @notice Thrown when the tranche duration is zero
    error ZeroTrancheDuration();

    /// @notice Thrown when the total tranches count is zero
    error ZeroTotalTranches();

    /// @notice Thrown when (totalTranches * trancheDuration) + cliff != durationSeconds
    error InvalidScheduleParams();

    /// @notice Thrown when attempting to revoke an already-revoked vesting wallet
    error AlreadyRevoked();

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------

    /// @notice Emitted when admin withdraws unvested tokens via `withdrawUnreleased`
    /// @param token The ERC-20 token address withdrawn (or address(0) for native ETH)
    /// @param amount The amount of tokens withdrawn
    event VestingRevoked(address indexed token, uint256 amount);

    // -------------------------------------------------------------------------
    // Initializer
    // -------------------------------------------------------------------------

    /// @notice Initializes the vesting wallet (called once via ERC-1967 proxy)
    /// @param beneficiary Address that will receive vested tokens upon `release()`
    /// @param startTimestamp Unix timestamp at which the vesting schedule begins
    /// @param durationSeconds Total vesting duration in seconds (cliff + tranches)
    /// @param cliffSeconds Length of the cliff period in seconds — no tokens unlock before this
    /// @param trancheDuration_ Duration of a single installment in seconds (e.g., 30 days)
    /// @param totalTranches_ Total number of equal tranche installments
    /// @param admin_ Address authorized to call `withdrawUnreleased`
    /// @param upgrader_ Address authorized to upgrade the implementation via UUPS
    function initialize(
        address beneficiary,
        uint64 startTimestamp,
        uint64 durationSeconds,
        uint64 cliffSeconds,
        uint64 trancheDuration_,
        uint64 totalTranches_,
        address admin_,
        address upgrader_
    ) external;

    // -------------------------------------------------------------------------
    // Release
    // -------------------------------------------------------------------------

    /// @notice Releases all currently vested ETH to the beneficiary
    function release() external;

    /// @notice Releases all currently vested ERC-20 `token` to the beneficiary
    /// @param token The ERC-20 token contract address to release
    function release(address token) external;

    /// @notice Returns the amount of ETH that has vested but not yet been released
    function releasable() external view returns (uint256);

    /// @notice Returns the amount of ERC-20 `token` that has vested but not yet been released
    /// @param token The ERC-20 token contract address
    function releasable(address token) external view returns (uint256);

    // -------------------------------------------------------------------------
    // Admin — Withdrawal of Unvested Tokens
    // -------------------------------------------------------------------------

    /// @notice Allows the admin to withdraw tokens that have not yet vested
    /// @dev Reverts if the contract has already been revoked
    /// @param token The ERC-20 token to withdraw (use `address(0)` for native ETH)
    /// @param to The recipient address for the withdrawn tokens
    function withdrawUnreleased(address token, address payable to) external;

    // -------------------------------------------------------------------------
    // Vesting Schedule Views
    // -------------------------------------------------------------------------

    /// @notice Returns the vesting beneficiary address
    function beneficiary() external view returns (address);

    /// @notice Returns the vesting start timestamp
    function start() external view returns (uint256);

    /// @notice Returns the total vesting duration in seconds
    function duration() external view returns (uint256);

    /// @notice Returns the cliff end timestamp (start + cliff period)
    function cliff() external view returns (uint256);

    /// @notice Returns the total amount of ETH that has been released so far
    function released() external view returns (uint256);

    /// @notice Returns the total amount of ERC-20 `token` that has been released so far
    /// @param token The ERC-20 token contract address
    function released(address token) external view returns (uint256);

    // -------------------------------------------------------------------------
    // Admin Views
    // -------------------------------------------------------------------------

    /// @notice Returns the address of the admin authorized to call `withdrawUnreleased`
    function admin() external view returns (address);

    /// @notice Returns the address of the upgrader authorized to upgrade the implementation
    function upgrader() external view returns (address);

    /// @notice Returns true if this vesting wallet has been revoked (unvested tokens withdrawn)
    function revoked() external view returns (bool);

    /// @notice Returns the duration of a single tranche installment in seconds
    function trancheDuration() external view returns (uint64);

    /// @notice Returns the total number of tranche installments
    function totalTranches() external view returns (uint64);
}
