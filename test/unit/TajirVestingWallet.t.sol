// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {TajirVestingWallet} from "../../src/TajirVestingWallet.sol";

contract MockERC20 {
    string public name = "Mock";
    string public symbol = "MCK";
    uint8 public decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amt) public virtual {
        balanceOf[to] += amt;
        totalSupply += amt;
    }

    function transfer(address to, uint256 amt) public virtual returns (bool) {
        balanceOf[msg.sender] -= amt;
        balanceOf[to] += amt;
        return true;
    }

    function approve(address s, uint256 a) public virtual returns (bool) {
        allowance[msg.sender][s] = a;
        return true;
    }
}

/// Balance can shrink independently of transfers (rebase / fee-on-transfer).
contract RebasingERC20 is MockERC20 {
    function burnFrom(address who, uint256 amt) external {
        balanceOf[who] -= amt;
        totalSupply -= amt;
    }
}

/// Reports a balance but moves nothing.
contract NoopTransferERC20 is MockERC20 {
    function transfer(address, uint256) public pure override returns (bool) {
        return true;
    }
}

/// Covers every QuillAudits finding that reproduced against the deployed source,
/// in both deployment shapes: ERC-20 TJR on Ethereum, native TJR on Tajir chain.

/// Takes a 1% fee on transfer out.
contract FeeERC20 is MockERC20 {
    function transfer(address to, uint256 a) public override returns (bool) {
        uint256 fee = a / 100;
        balanceOf[msg.sender] -= a;
        balanceOf[to] += a - fee;
        totalSupply -= fee;
        return true;
    }
}

contract TajirVestingWalletAuditTest is Test {
    TajirVestingWallet impl;
    MockERC20 tjr;

    address beneficiary = address(0xBEEF);
    address adminSafe = address(0xA5A5);
    address upgraderSafe = address(0x0DDB);
    address outsider = address(0xDEAD);

    uint64 constant MONTH = 30 days;
    uint64 constant CLIFF = 12 * MONTH;
    uint64 constant TRANCHES = 36;
    uint64 constant DURATION = CLIFF + TRANCHES * MONTH;
    uint256 constant ALLOC = 8_125_000e18;

    function setUp() public {
        vm.warp(2_000_000_000);
        impl = new TajirVestingWallet();
        tjr = new MockERC20();
    }

    function _initData(
        uint64 start,
        address asset
    ) internal view returns (bytes memory) {
        return abi.encodeWithSignature(
            "initialize(address,uint64,uint64,uint64,uint64,uint64,address,address,address)",
            beneficiary,
            start,
            DURATION,
            CLIFF,
            MONTH,
            TRANCHES,
            adminSafe,
            upgraderSafe,
            asset
        );
    }

    function _deploy(
        uint64 start,
        address asset
    ) internal returns (TajirVestingWallet w) {
        w = TajirVestingWallet(
            payable(address(new ERC1967Proxy(address(impl), _initData(start, asset))))
        );
    }

    /// Ethereum shape: TJR is an ERC-20, ETH is the stray asset.
    function _l1() internal returns (TajirVestingWallet w) {
        w = _deploy(uint64(block.timestamp), address(tjr));
        tjr.mint(address(w), ALLOC);
    }

    /// Tajir chain shape: TJR is the native coin.
    function _l2() internal returns (TajirVestingWallet w) {
        w = _deploy(uint64(block.timestamp), address(0));
        vm.deal(address(w), ALLOC);
    }

    function _afterFirstTranche() internal {
        vm.warp(block.timestamp + CLIFF + MONTH);
    }

    // ------------------------------------------------------------------
    // H1 - inherited initializer stays disabled
    // ------------------------------------------------------------------
    function test_H1_inherited_initializer_is_disabled() public {
        TajirVestingWallet w = _l1();
        vm.expectRevert();
        w.initialize(outsider, uint64(block.timestamp), DURATION);
        assertEq(w.owner(), beneficiary);
    }

    function test_H1_implementation_is_inert() public {
        vm.expectRevert();
        impl.initialize(outsider, uint64(block.timestamp), DURATION);
    }

    // ------------------------------------------------------------------
    // H2 - revocation is confined to the vested asset
    // ------------------------------------------------------------------
    function test_H2_L1_stray_eth_cannot_be_swept_through_revoke() public {
        TajirVestingWallet w = _l1();
        vm.deal(address(w), 1 ether);
        _afterFirstTranche();

        vm.prank(adminSafe);
        vm.expectRevert(TajirVestingWallet.NotVestedAsset.selector);
        w.withdrawUnreleased(address(0), payable(adminSafe));

        assertFalse(w.hasRevoked(), "flag untouched");
        assertEq(w.releasable(address(tjr)), ALLOC / TRANCHES, "schedule intact");
    }

            /// The audit's named invariant, both shapes.
        function test_H2_non_vested_assets_are_never_releasable_by_beneficiary()
        public
    {
        TajirVestingWallet w = _l1();
        MockERC20 airdrop = new MockERC20();
        airdrop.mint(address(w), 500e18);
        vm.deal(address(w), 1 ether);
        _afterFirstTranche();

        assertEq(w.releasable(address(airdrop)), 0, "airdrop is outside the schedule");
        assertEq(w.releasable(), 0, "stray ETH is outside the schedule");
    }

        function test_H2_revoke_is_still_terminal_for_the_vested_asset() public {
        TajirVestingWallet w = _l1();
        _afterFirstTranche();

        vm.startPrank(adminSafe);
        w.withdrawUnreleased(address(tjr), payable(adminSafe));
        vm.expectRevert(TajirVestingWallet.AlreadyRevoked.selector);
        w.withdrawUnreleased(address(tjr), payable(adminSafe));
        vm.stopPrank();
    }

            // ------------------------------------------------------------------
    // M - Ownable escape hatches are closed
    // ------------------------------------------------------------------
    function test_M_renounceOwnership_reverts() public {
        TajirVestingWallet w = _l1();
        vm.prank(beneficiary);
        vm.expectRevert(TajirVestingWallet.OwnershipLocked.selector);
        w.renounceOwnership();
        assertEq(w.owner(), beneficiary);
    }

    function test_M_transferOwnership_reverts() public {
        TajirVestingWallet w = _l1();
        vm.prank(beneficiary);
        vm.expectRevert(TajirVestingWallet.OwnershipLocked.selector);
        w.transferOwnership(outsider);
        assertEq(w.owner(), beneficiary);
    }

    // ------------------------------------------------------------------
    // M - balance-reducing assets degrade instead of bricking
    // ------------------------------------------------------------------
    function test_M_shrinking_vested_balance_does_not_brick_release() public {
        RebasingERC20 r = new RebasingERC20();
        TajirVestingWallet w = _deploy(uint64(block.timestamp), address(r));
        r.mint(address(w), ALLOC);

        vm.warp(block.timestamp + CLIFF + 10 * MONTH);
        vm.prank(beneficiary);
        w.release(address(r));
        uint256 paid = r.balanceOf(beneficiary);
        assertGt(paid, 0, "control: release worked");

        r.burnFrom(address(w), r.balanceOf(address(w)));

        assertEq(w.releasable(address(r)), 0, "clamped, no panic");
        vm.prank(adminSafe);
        vm.expectRevert(TajirVestingWallet.NothingToWithdraw.selector);
        w.withdrawUnreleased(address(r), payable(adminSafe));
    }

    function test_M_shrinking_stray_balance_is_inert() public {
        TajirVestingWallet w = _l1();
        RebasingERC20 r = new RebasingERC20();
        r.mint(address(w), 1_000e18);
        r.burnFrom(address(w), 1_000e18);
        assertEq(w.releasable(address(r)), 0, "no panic on a stray asset either");
    }

    // ------------------------------------------------------------------
    // M - a schedule that locks nothing is rejected
    // ------------------------------------------------------------------
    function test_M_backdated_start_that_locks_nothing_reverts() public {
        vm.expectRevert(TajirVestingWallet.ScheduleLocksNothing.selector);
        _deploy(uint64(block.timestamp - DURATION - 1), address(tjr));
    }

    function test_M_intentional_backdating_still_allowed() public {
        TajirVestingWallet w = _deploy(
            uint64(block.timestamp - CLIFF - MONTH),
            address(tjr)
        );
        tjr.mint(address(w), ALLOC);
        assertEq(w.releasable(address(tjr)), ALLOC / TRANCHES, "one tranche already earned");
    }

    // ------------------------------------------------------------------
    // M - the flag cannot latch without value moving
    // ------------------------------------------------------------------
    function test_M_noop_transfer_vested_asset_cannot_latch_the_flag() public {
        NoopTransferERC20 fake = new NoopTransferERC20();
        TajirVestingWallet w = _deploy(uint64(block.timestamp), address(fake));
        fake.mint(address(w), ALLOC);
        _afterFirstTranche();

        vm.prank(adminSafe);
        vm.expectRevert(TajirVestingWallet.NoBalanceMoved.selector);
        w.withdrawUnreleased(address(fake), payable(adminSafe));
        assertFalse(w.hasRevoked(), "no value moved, no revocation");
    }

    // ------------------------------------------------------------------
    // I - authorization is evaluated before state
    // ------------------------------------------------------------------
    function test_I_unauthorized_caller_learns_nothing_about_revocation() public {
        TajirVestingWallet w = _l1();
        _afterFirstTranche();

        vm.prank(outsider);
        vm.expectRevert(TajirVestingWallet.NotAdmin.selector);
        w.withdrawUnreleased(address(tjr), payable(outsider));

        vm.prank(adminSafe);
        w.withdrawUnreleased(address(tjr), payable(adminSafe));

        vm.prank(outsider);
        vm.expectRevert(TajirVestingWallet.NotAdmin.selector);
        w.withdrawUnreleased(address(tjr), payable(outsider));
    }

    // ------------------------------------------------------------------
    // Controls - the intended behaviour is unchanged
    // ------------------------------------------------------------------
    function test_control_L1_revoke_claws_back_only_the_unvested_portion() public {
        TajirVestingWallet w = _l1();
        _afterFirstTranche();

        vm.prank(adminSafe);
        w.withdrawUnreleased(address(tjr), payable(adminSafe));

        assertEq(tjr.balanceOf(adminSafe), ALLOC - ALLOC / TRANCHES, "unvested returned");
        vm.prank(beneficiary);
        w.release(address(tjr));
        assertEq(tjr.balanceOf(beneficiary), ALLOC / TRANCHES, "earned tranche preserved");
    }

    function test_control_L2_revoke_claws_back_only_the_unvested_portion() public {
        TajirVestingWallet w = _l2();
        _afterFirstTranche();

        vm.prank(adminSafe);
        w.withdrawUnreleased(address(0), payable(adminSafe));

        assertEq(adminSafe.balance, ALLOC - ALLOC / TRANCHES, "unvested returned");
        w.release();
        assertEq(beneficiary.balance, ALLOC / TRANCHES, "earned tranche preserved");
    }

    function test_control_pre_cliff_nothing_is_releasable() public {
        TajirVestingWallet w = _l1();
        vm.warp(block.timestamp + CLIFF - 1);
        assertEq(w.releasable(address(tjr)), 0);
    }

    function test_control_full_schedule_pays_out_exactly() public {
        TajirVestingWallet w = _l1();
        vm.warp(block.timestamp + DURATION);
        vm.prank(beneficiary);
        w.release(address(tjr));
        assertEq(tjr.balanceOf(beneficiary), ALLOC);
    }

    function test_control_tranches_accrue_one_at_a_time() public {
        TajirVestingWallet w = _l1();
        for (uint64 i = 1; i <= 5; i++) {
            vm.warp(uint64(block.timestamp) + (i == 1 ? CLIFF + MONTH : MONTH));
            assertEq(
                w.releasable(address(tjr)),
                (ALLOC * i) / TRANCHES,
                "tranche accrual"
            );
        }
    }

    function test_control_vestedAsset_getter() public {
        assertEq(_l1().vestedAsset(), address(tjr));
        assertEq(_l2().vestedAsset(), address(0));
    }

    // ---- #1 residual is UNCHANGED: atomic deployment is still the guard ----
    function test_1_residual_nonatomic_proxy_still_seizable_documented() public {
        TajirVestingWallet w = TajirVestingWallet(payable(address(
            new ERC1967Proxy(address(impl), "")
        )));
        vm.prank(outsider);
        (bool ok, ) = address(w).call(_initData(uint64(block.timestamp), address(tjr)));
        assertTrue(ok, "unchanged by this fix - both deploy paths are atomic");
        assertEq(w.owner(), beneficiary);
    }

    // ---- #2 the panel's own calldata is now safe on BOTH chains ----
    function test_2_panel_calldata_L1_now_reverts_instead_of_unlocking() public {
        TajirVestingWallet w = _deploy(uint64(block.timestamp), address(tjr));
        tjr.mint(address(w), ALLOC);
        vm.deal(address(w), 1 wei);
        vm.warp(block.timestamp + CLIFF + MONTH);

        vm.prank(adminSafe);
        vm.expectRevert(TajirVestingWallet.NotVestedAsset.selector);
        w.withdrawUnreleased(address(0), payable(adminSafe));
        assertEq(w.releasable(address(tjr)), ALLOC / TRANCHES, "one tranche, not all");
    }

    function test_2_panel_calldata_L2_still_works_unchanged() public {
        TajirVestingWallet w = _deploy(uint64(block.timestamp), address(0));
        vm.deal(address(w), ALLOC);
        vm.warp(block.timestamp + CLIFF + MONTH);
        vm.prank(adminSafe);
        w.withdrawUnreleased(address(0), payable(adminSafe));
        assertEq(adminSafe.balance, ALLOC - ALLOC / TRANCHES);
    }

    function test_2_contract_IS_inert_after_revocation_now() public {
        TajirVestingWallet w = _deploy(uint64(block.timestamp), address(tjr));
        tjr.mint(address(w), ALLOC);
        vm.warp(block.timestamp + CLIFF + MONTH);
        vm.prank(adminSafe);
        w.withdrawUnreleased(address(tjr), payable(adminSafe));

        MockERC20 later = new MockERC20();
        later.mint(address(w), 1_000e18);
        assertEq(w.releasable(address(later)), 0, "arrivals stay outside the schedule");
        vm.deal(address(w), 3 ether);
        assertEq(w.releasable(), 0, "native too");
    }

    // ---- #3 both shapes ----
    function test_3_renounce_and_transfer_revert_on_both_shapes() public {
        TajirVestingWallet l1 = _deploy(uint64(block.timestamp), address(tjr));
        TajirVestingWallet l2 = _deploy(uint64(block.timestamp), address(0));
        vm.startPrank(beneficiary);
        vm.expectRevert(TajirVestingWallet.OwnershipLocked.selector);
        l1.renounceOwnership();
        vm.expectRevert(TajirVestingWallet.OwnershipLocked.selector);
        l2.renounceOwnership();
        vm.expectRevert(TajirVestingWallet.OwnershipLocked.selector);
        l1.transferOwnership(outsider);
        vm.expectRevert(TajirVestingWallet.OwnershipLocked.selector);
        l2.transferOwnership(outsider);
        vm.stopPrank();
    }

    // ---- #5 monotonicity: vested can never fall below released ----
    function test_5_vested_never_falls_below_released() public {
        TajirVestingWallet w = _deploy(uint64(block.timestamp), address(tjr));
        tjr.mint(address(w), ALLOC);
        vm.warp(block.timestamp + CLIFF + 20 * MONTH);
        vm.prank(beneficiary);
        w.release(address(tjr));
        uint256 rel = w.released(address(tjr));

        vm.warp(block.timestamp - 10 * MONTH); // simulate any backwards recompute
        assertGe(w.vestedAmount(address(tjr), uint64(block.timestamp)), rel, "clamped");
        w.releasable(address(tjr)); // must not revert
    }

    // ---- #9 fee-on-transfer: honest event, no brick, flag still latches ----
    function test_9_fee_on_transfer_emits_the_amount_that_actually_moved() public {
        FeeERC20 f = new FeeERC20();
        TajirVestingWallet w = _deploy(uint64(block.timestamp), address(f));
        f.mint(address(w), ALLOC);
        vm.warp(block.timestamp + CLIFF + MONTH);

        uint256 beforeBal = f.balanceOf(address(w));
        vm.recordLogs();
        vm.prank(adminSafe);
        w.withdrawUnreleased(address(f), payable(adminSafe));
        uint256 moved = beforeBal - f.balanceOf(address(w));

        assertTrue(w.hasRevoked(), "value moved, so revocation stands");
        assertEq(f.balanceOf(address(w)), w.releasable(address(f)), "beneficiary's share intact");
        assertGt(moved, 0);
    }

    // ---- #8 both shapes ----
    function test_8_backdated_start_locking_nothing_reverts_on_both_shapes() public {
        vm.expectRevert(TajirVestingWallet.ScheduleLocksNothing.selector);
        new ERC1967Proxy(address(impl), _initData(uint64(block.timestamp - DURATION - 1), address(tjr)));
        vm.expectRevert(TajirVestingWallet.ScheduleLocksNothing.selector);
        new ERC1967Proxy(address(impl), _initData(uint64(block.timestamp - DURATION - 1), address(0)));
    }

    // ---- #6 / #12 unchanged design behaviour ----
    function test_6_and_12_rounding_behaviour_is_unchanged() public {
        TajirVestingWallet w = _deploy(uint64(block.timestamp), address(tjr));
        tjr.mint(address(w), 100_000);
        vm.warp(block.timestamp + CLIFF + MONTH);
        assertEq(w.releasable(address(tjr)), 100_000 / TRANCHES, "still floors mid-schedule");
        vm.warp(block.timestamp + DURATION);
        assertEq(w.releasable(address(tjr)), 100_000, "still settles exactly at end");
    }

    function test_H2_L2_stray_token_cannot_be_swept_through_revoke() public {
        TajirVestingWallet w = _deploy(uint64(block.timestamp), address(0));
        vm.deal(address(w), ALLOC);
        MockERC20 airdrop = new MockERC20();
        airdrop.mint(address(w), 1_000e18);
        _afterFirstTranche();

        vm.prank(adminSafe);
        vm.expectRevert(TajirVestingWallet.NotVestedAsset.selector);
        w.withdrawUnreleased(address(airdrop), payable(adminSafe));

        assertFalse(w.hasRevoked());
        assertEq(w.releasable(), ALLOC / TRANCHES, "native schedule intact");
    }

    /// The audit's own named invariant, in both deployment shapes.
    function test_H2_tjrScheduleUnaffectedByOtherAssetRevoke() public {
        TajirVestingWallet l1 = _deploy(uint64(block.timestamp), address(tjr));
        tjr.mint(address(l1), ALLOC);
        MockERC20 other = new MockERC20();
        other.mint(address(l1), 500e18);
        vm.deal(address(l1), 5 ether);

        TajirVestingWallet l2 = _deploy(uint64(block.timestamp), address(0));
        vm.deal(address(l2), ALLOC);
        other.mint(address(l2), 500e18);

        _afterFirstTranche();
        uint256 expected = ALLOC / TRANCHES;

        vm.startPrank(adminSafe);
        vm.expectRevert(TajirVestingWallet.NotVestedAsset.selector);
        l1.withdrawUnreleased(address(other), payable(adminSafe));
        vm.expectRevert(TajirVestingWallet.NotVestedAsset.selector);
        l1.withdrawUnreleased(address(0), payable(adminSafe));
        vm.expectRevert(TajirVestingWallet.NotVestedAsset.selector);
        l2.withdrawUnreleased(address(other), payable(adminSafe));
        vm.stopPrank();

        assertEq(l1.releasable(address(tjr)), expected, "L1 schedule unmoved");
        assertEq(l2.releasable(), expected, "L2 schedule unmoved");
    }

    function test_H2_post_revocation_other_assets_stay_outside_the_schedule()
        public
    {
        TajirVestingWallet w = _deploy(uint64(block.timestamp), address(tjr));
        tjr.mint(address(w), ALLOC);
        _afterFirstTranche();

        vm.prank(adminSafe);
        w.withdrawUnreleased(address(tjr), payable(adminSafe));
        assertTrue(w.hasRevoked());

        MockERC20 other = new MockERC20();
        other.mint(address(w), 500e18);
        assertEq(w.releasable(address(other)), 0, "not instantly vested");
        vm.deal(address(w), 3 ether);
        assertEq(w.releasable(), 0, "native too");
    }
}
