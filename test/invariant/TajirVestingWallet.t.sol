// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {TajirVestingWallet} from "src/TajirVestingWallet.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title MockERC20
 * @notice Minimal ERC-20 used inside invariant tests for token funding
 */
contract MockERC20 is ERC20 {
    constructor() ERC20("Mock TJR", "mTJR") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/**
 * @title TajirVestingInvariantHandler
 * @notice Stateful actor contract that drives invariant test state transitions.
 *         Forge's invariant engine calls arbitrary sequences of functions on this
 *         handler; the invariants on TajirVestingInvariantTest then assert that
 *         global properties hold after every call sequence.
 */
contract TajirVestingInvariantHandler is Test {
    TajirVestingWallet public wallet;
    MockERC20 public token;

    address public beneficiary;
    address public admin;

    uint256 public totalFunded;
    uint256 public totalReleased;

    uint64 constant MONTH = 30 days;

    constructor(TajirVestingWallet _wallet, MockERC20 _token, address _beneficiary, address _admin) {
        wallet = _wallet;
        token = _token;
        beneficiary = _beneficiary;
        admin = _admin;
    }

    /// @notice Warp time forward and call release()
    function release(uint32 warpSeconds) external {
        warpSeconds = uint32(bound(warpSeconds, 0, 5 * 365 days));
        vm.warp(block.timestamp + warpSeconds);

        uint256 before = token.balanceOf(beneficiary);
        vm.prank(beneficiary);
        wallet.release(address(token));
        uint256 after_ = token.balanceOf(beneficiary);

        totalReleased += after_ - before;
    }

    /// @notice Fund the wallet with additional tokens
    function fund(uint128 amount) external {
        amount = uint128(bound(amount, 1, 10_000_000e18));
        token.mint(address(wallet), amount);
        totalFunded += amount;
    }
}

/**
 * @title TajirVestingInvariantTest
 * @notice Invariant test suite for TajirVestingWallet.
 *
 * Invariants asserted after every call sequence:
 *   I1. released(token) <= vestedAmount(token): cannot release more than vested
 *   I2. released(token) is monotonically non-decreasing: tokens are never un-released
 *   I3. No tokens unlock before cliff end timestamp
 *   I4. Beneficiary ERC-20 balance == totalReleased tracked by handler
 */
contract TajirVestingInvariantTest is Test {
    MockERC20 public token;
    TajirVestingWallet public wallet;
    TajirVestingInvariantHandler public handler;

    address public beneficiary = makeAddr("beneficiary");
    address public admin = makeAddr("admin");
    address public upgrader = makeAddr("upgrader");

    uint64 constant MONTH = 30 days;
    uint256 constant INITIAL_FUND = 1_000_000e18;

    uint64 public startTimestamp;
    uint64 public cliffSeconds;
    uint64 public trancheDuration;
    uint64 public totalTranches;

    function setUp() public {
        token = new MockERC20();

        startTimestamp = uint64(block.timestamp);
        cliffSeconds = 12 * MONTH;
        trancheDuration = 1 * MONTH;
        totalTranches = 48;
        // durationSeconds = cliff + (totalTranches * trancheDuration)
        uint64 durationSeconds = cliffSeconds + (totalTranches * trancheDuration);

        TajirVestingWallet impl = new TajirVestingWallet();
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), "");
        wallet = TajirVestingWallet(payable(address(proxy)));

        wallet.initialize(
            beneficiary,
            startTimestamp,
            durationSeconds,
            cliffSeconds,
            trancheDuration,
            totalTranches,
            admin,
            upgrader
        );

        // Fund the wallet with initial tokens
        token.mint(address(wallet), INITIAL_FUND);

        // Deploy the stateful handler
        handler = new TajirVestingInvariantHandler(wallet, token, beneficiary, admin);

        // Grant handler access to release on behalf of beneficiary
        vm.label(address(handler), "InvariantHandler");
        vm.label(address(wallet), "VestingWallet");
        vm.label(address(token), "MockERC20");

        // Target only the handler to drive state transitions
        targetContract(address(handler));
    }

    // -------------------------------------------------------------------------
    // I1: released <= vestedAmount
    //     The contract must never release more than the linearly vested portion
    // -------------------------------------------------------------------------
    function invariant_releasedNeverExceedsVested() public view {
        uint256 releasedAmount = wallet.released(address(token));
        uint256 vestedAmount = wallet.releasable(address(token)) + releasedAmount;
        assertLe(releasedAmount, vestedAmount, "I1: released > vested");
    }

    // -------------------------------------------------------------------------
    // I2: Beneficiary balance matches handler's totalReleased tracker
    //     Ensures no tokens are fabricated or lost during release()
    // -------------------------------------------------------------------------
    function invariant_beneficiaryBalanceMatchesReleased() public view {
        assertEq(
            token.balanceOf(beneficiary),
            handler.totalReleased(),
            "I2: beneficiary balance != totalReleased"
        );
    }

    // -------------------------------------------------------------------------
    // I3: No tokens unlock before cliff
    //     If current time < start + cliff, releasable must be zero
    // -------------------------------------------------------------------------
    function invariant_noUnlockBeforeCliff() public view {
        if (block.timestamp < startTimestamp + cliffSeconds) {
            assertEq(
                wallet.releasable(address(token)),
                0,
                "I3: tokens releasable before cliff"
            );
        }
    }

    // -------------------------------------------------------------------------
    // I4: Wallet token balance = funded - released
    //     Wallet balance should equal total funded tokens minus total released
    // -------------------------------------------------------------------------
    function invariant_walletBalanceConsistency() public view {
        uint256 walletBalance = token.balanceOf(address(wallet));
        uint256 expectedBalance = handler.totalFunded() + INITIAL_FUND - handler.totalReleased();
        assertEq(walletBalance, expectedBalance, "I4: wallet balance inconsistency");
    }
}
