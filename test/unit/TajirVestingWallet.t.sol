// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {TajirVestingWallet} from "src/TajirVestingWallet.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock ERC20", "MERC20") {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

/**
 * @title TajirVestingTest
 * @notice Comprehensive test suite for TJR vesting contracts
 */
contract TajirVestingTest is Test {
    MockERC20 public token;
    TajirVestingWallet public vestingWallet;

    address public admin = vm.addr(1);
    address public pauser = vm.addr(2);
    address public beneficiary = vm.addr(3);

    uint64 public constant MONTH = 30 days;
    uint64 public constant YEAR = 12 * MONTH;

    uint64 public startTimestamp;
    uint256 public vestingAmount = 100_000e18; // 100k TJR for testing

    function setUp() public {
        token = new MockERC20();

        // Set start timestamp to current block time
        startTimestamp = uint64(block.timestamp);
    }

    /// @dev Helper to create vesting wallet with given parameters
    function _createVestingWallet(
        uint64 duration,
        uint64 cliff,
        uint64 trancheDuration,
        uint64 totalTranches
    ) internal returns (TajirVestingWallet) {
        TajirVestingWallet walletImpl = new TajirVestingWallet();
        ERC1967Proxy proxyVest = new ERC1967Proxy(address(walletImpl), "");
        TajirVestingWallet wallet = TajirVestingWallet(
            payable(address(proxyVest))
        );
        wallet.initialize(
            beneficiary,
            startTimestamp,
            duration,
            cliff,
            trancheDuration,
            totalTranches,
            admin,
            admin,
            address(0)
        );

        // Fund the vesting wallet with native tokens
        vm.deal(address(wallet), vestingAmount);

        return wallet;
    }

    /// @dev Helper to create a wallet that vests an ERC-20 rather than the native coin
    function _createErc20VestingWallet(
        address asset,
        uint64 duration,
        uint64 cliff,
        uint64 trancheDuration,
        uint64 totalTranches
    ) internal returns (TajirVestingWallet) {
        bytes memory initData = abi.encodeWithSignature(
            "initialize(address,uint64,uint64,uint64,uint64,uint64,address,address,address)",
            beneficiary,
            startTimestamp,
            duration,
            cliff,
            trancheDuration,
            totalTranches,
            admin,
            admin,
            asset
        );
        return
            TajirVestingWallet(
                payable(
                    address(
                        new ERC1967Proxy(
                            address(new TajirVestingWallet()),
                            initData
                        )
                    )
                )
            );
    }

    /*//////////////////////////////////////////////////////////////
                         DEPLOYMENT TESTS
    //////////////////////////////////////////////////////////////*/

    function testDeployVestingWallet() public {
        uint64 duration = 42 * MONTH;
        uint64 cliff = 6 * MONTH;

        vestingWallet = _createVestingWallet(duration, cliff, MONTH * 2, 18);

        assertEq(vestingWallet.owner(), beneficiary);
        assertEq(vestingWallet.start(), startTimestamp);
        assertEq(vestingWallet.duration(), duration);
        assertEq(vestingWallet.end(), startTimestamp + duration);
        assertEq(vestingWallet.cliff(), startTimestamp + cliff);
        assertEq(address(vestingWallet).balance, vestingAmount);
        assertEq(vestingWallet.trancheDuration(), MONTH * 2);
        assertEq(vestingWallet.totalTranches(), 18);
    }

    function testRevertsInitializeWithThreeParams() public {
        TajirVestingWallet walletImpl = new TajirVestingWallet();
        ERC1967Proxy proxyVest = new ERC1967Proxy(address(walletImpl), "");
        TajirVestingWallet wallet = TajirVestingWallet(
            payable(address(proxyVest))
        );

        vm.expectRevert("TajirVestingWallet: use the 9-argument initialize.");
        wallet.initialize(beneficiary, startTimestamp, 48 * MONTH);
    }

    function testRevertsAtInitialize() public {
        uint64 cliff = 12 * MONTH;
        uint64 trancheDur = MONTH;
        uint64 totalTranches = 18;
        uint64 duration = 48 * MONTH;

        TajirVestingWallet walletImpl = new TajirVestingWallet();
        ERC1967Proxy proxyVest = new ERC1967Proxy(address(walletImpl), "");
        TajirVestingWallet wallet = TajirVestingWallet(
            payable(address(proxyVest))
        );

        vm.expectRevert(TajirVestingWallet.ZeroTrancheDuration.selector);
        wallet.initialize(
            beneficiary,
            startTimestamp,
            duration,
            cliff,
            0,
            totalTranches,
            admin,
            admin,
            address(0)
        );

        vm.expectRevert(TajirVestingWallet.ZeroTotalTranches.selector);
        wallet.initialize(
            beneficiary,
            startTimestamp,
            duration,
            cliff,
            trancheDur,
            0,
            admin,
            admin,
            address(0)
        );

        vm.expectRevert(TajirVestingWallet.InvalidScheduleParams.selector);
        wallet.initialize(
            beneficiary,
            startTimestamp,
            duration,
            cliff,
            trancheDur,
            trancheDur,
            admin,
            admin,
            address(0)
        );
    }

    /*//////////////////////////////////////////////////////////////
                        CLIFF FUNCTIONALITY TESTS
    //////////////////////////////////////////////////////////////*/

    function testNoTokensReleasableBeforeCliff() public {
        uint64 duration = 42 * MONTH;
        uint64 cliff = 6 * MONTH;

        vestingWallet = _createVestingWallet(duration, cliff, MONTH * 2, 18);

        // Check at various points before cliff
        uint256[] memory checkpoints = new uint256[](3);
        checkpoints[0] = startTimestamp + 1 days;
        checkpoints[1] = startTimestamp + 3 * MONTH;
        checkpoints[2] = startTimestamp + cliff - 1 days;

        for (uint256 i = 0; i < checkpoints.length; i++) {
            vm.warp(checkpoints[i]);
            assertEq(
                vestingWallet.releasable(),
                0,
                "Tokens should not be releasable before cliff"
            );
        }
    }

    function testTokensNotReleasableEvenAfterCliff() public {
        uint64 duration = 42 * MONTH;
        uint64 cliff = 6 * MONTH;

        vestingWallet = _createVestingWallet(duration, cliff, MONTH * 2, 18);

        // Warp to just after cliff
        vm.warp(startTimestamp + cliff + 1 days);

        uint256 releasable = vestingWallet.releasable();
        assertEq(
            releasable,
            0,
            "Tokens should not be releasable even after cliff"
        );
    }

    function testNoCliffVesting() public {
        uint64 duration = 24 * MONTH;
        uint64 cliff = 0; // No cliff

        vestingWallet = _createVestingWallet(duration, cliff, MONTH, 24);

        // Warp to 1 day after start
        vm.warp(startTimestamp + 1 days);

        uint256 releasable = vestingWallet.releasable();
        assertEq(
            releasable,
            0,
            "Tokens should not be releasable even after cliff"
        );
    }

    /*//////////////////////////////////////////////////////////////
                           VESTING TESTS
    //////////////////////////////////////////////////////////////*/

    function testScenario1() public {
        // 12 months cliff, 36 months Vesting, 2 months frequency = 18 tranches
        // Total duration = 48 months
        uint64 cliff = 12 * MONTH;
        uint64 trancheDur = 2 * MONTH;
        uint64 totalTranches = 18;
        uint64 duration = 48 * MONTH;

        vestingWallet = _createVestingWallet(
            duration,
            cliff,
            trancheDur,
            totalTranches
        );

        // Before Cliff (Month 11) -> 0%
        vm.warp(startTimestamp + 11 * MONTH);
        assertEq(vestingWallet.releasable(), 0);

        // At Cliff (Month 12) -> Still 0% (Requirement: zero tokens during cliff)
        vm.warp(startTimestamp + 12 * MONTH);
        assertEq(vestingWallet.releasable(), 0);

        // First Tranche (Month 14) -> 1/18
        vm.warp(startTimestamp + 14 * MONTH);
        assertEq(vestingWallet.releasable(), vestingAmount / 18);

        // Middle (Month 30) -> 9 tranches (12 cliff + 9 * 2m = 30m)
        vm.warp(startTimestamp + 30 * MONTH);
        assertEq(vestingWallet.releasable(), (vestingAmount * 9) / 18);

        // Final (Month 48) -> 18/18
        vm.warp(startTimestamp + 48 * MONTH);
        assertEq(vestingWallet.releasable(), vestingAmount);
    }

    function testScenario2() public {
        // 6 months cliff, 12 months Vesting, 1 month frequency = 12 tranches
        // Total duration = 18 months
        uint64 cliff = 6 * MONTH;
        uint64 trancheDur = MONTH;
        uint64 totalTranches = 12;
        uint64 duration = 18 * MONTH;

        vestingWallet = _createVestingWallet(
            duration,
            cliff,
            trancheDur,
            totalTranches
        );

        // At Cliff (Month 6) -> 0%
        vm.warp(startTimestamp + 6 * MONTH);
        assertEq(vestingWallet.releasable(), 0);

        // First Tranche (Month 7) -> 1/12
        vm.warp(startTimestamp + 7 * MONTH);
        assertEq(vestingWallet.releasable(), vestingAmount / 12);

        // Final (Month 18) -> 12/12
        vm.warp(startTimestamp + 18 * MONTH);
        assertEq(vestingWallet.releasable(), vestingAmount);
    }

    function testStepBehaviorNoLinearUnlock() public {
        // Using Team scenario: 2 months frequency
        uint64 cliff = 12 * MONTH;
        uint64 trancheDur = 2 * MONTH;
        uint64 totalTranches = 18;
        uint64 duration = 48 * MONTH;

        vestingWallet = _createVestingWallet(
            duration,
            cliff,
            trancheDur,
            totalTranches
        );

        // Warp to Month 14 (Tranche 1 unlocked)
        vm.warp(startTimestamp + 14 * MONTH);
        uint256 amountAtMonth14 = vestingWallet.releasable();
        assertEq(amountAtMonth14, vestingAmount / 18);

        // Warp to Month 15 (Halfway to next tranche)
        // In linear vesting, this would increase. In tranche vesting, it MUST NOT increase.
        vm.warp(startTimestamp + 15 * MONTH);
        uint256 amountAtMonth15 = vestingWallet.releasable();
        assertEq(
            amountAtMonth15,
            amountAtMonth14,
            "Amount should not increase between tranches"
        );

        // Warp to Month 16 (Tranche 2 unlocked)
        vm.warp(startTimestamp + 16 * MONTH);
        assertEq(vestingWallet.releasable(), (vestingAmount * 2) / 18);
    }

    /*//////////////////////////////////////////////////////////////
                           ADMIN WITHDRAW
    //////////////////////////////////////////////////////////////*/

    function testAdminWithdrawUnreleasedNative() public {
        // 12 months cliff, 2 months frequency, 18 tranches
        uint64 cliff = 12 * MONTH;
        uint64 trancheDur = 2 * MONTH;
        uint64 totalTranches = 18;
        uint64 duration = 48 * MONTH;

        vestingWallet = _createVestingWallet(
            duration,
            cliff,
            trancheDur,
            totalTranches
        );

        // Warp to Month 14 (1 tranche passed)
        vm.warp(startTimestamp + 14 * MONTH);

        uint256 expectedVested = vestingAmount / 18;
        uint256 expectedClaimable = expectedVested; // No release yet
        uint256 expectedWithdrawable = vestingAmount - expectedClaimable;

        assertEq(vestingWallet.releasable(), expectedClaimable);

        uint256 adminBalBefore = admin.balance;

        assertEq(vestingWallet.hasRevoked(), false);

        vm.prank(admin);
        vestingWallet.withdrawUnreleased(address(0), payable(admin));

        assertEq(
            admin.balance,
            adminBalBefore + expectedWithdrawable,
            "Admin should receive unreleased amount"
        );
        assertEq(
            address(vestingWallet).balance,
            expectedClaimable,
            "Claimable amount should remain in contract"
        );

        // Verify beneficiary can still claim the claimable amount
        uint256 beneficiaryBalBefore = beneficiary.balance;
        vm.prank(beneficiary);
        vestingWallet.release();

        assertEq(
            beneficiary.balance,
            beneficiaryBalBefore + expectedClaimable,
            "Beneficiary should receive claimable amount"
        );
        assertEq(address(vestingWallet).balance, 0, "Contract should be empty");
        assertEq(vestingWallet.hasRevoked(), true);
    }

    function testAdminWithdrawUnreleasedFailsIfNotAdmin() public {
        uint64 cliff = 12 * MONTH;
        uint64 trancheDur = 2 * MONTH;
        uint64 totalTranches = 18;
        uint64 duration = 48 * MONTH;

        vestingWallet = _createVestingWallet(
            duration,
            cliff,
            trancheDur,
            totalTranches
        );

        vm.prank(beneficiary);
        vm.expectRevert(TajirVestingWallet.NotAdmin.selector);
        vestingWallet.withdrawUnreleased(address(0), payable(beneficiary));
    }

    function testAdminWithdrawUnreleasedFailsIfNothingToWithdraw() public {
        uint64 cliff = 12 * MONTH;
        uint64 trancheDur = 2 * MONTH;
        uint64 totalTranches = 18;
        uint64 duration = 48 * MONTH;

        vestingWallet = _createVestingWallet(
            duration,
            cliff,
            trancheDur,
            totalTranches
        );

        // Warp to end
        vm.warp(startTimestamp + duration + 1 days);

        // At end, everything is vested/claimable. Nothing is unreleased.
        vm.prank(admin);
        vm.expectRevert(TajirVestingWallet.NothingToWithdraw.selector);
        vestingWallet.withdrawUnreleased(address(0), payable(admin));
    }

    /*//////////////////////////////////////////////////////////////
                           UPGRADE TESTS
    //////////////////////////////////////////////////////////////*/

    function testUpgradeImplementation() public {
        vm.startPrank(admin);

        TajirVestingWallet walletImpl = new TajirVestingWallet();
        ERC1967Proxy proxyVest = new ERC1967Proxy(address(walletImpl), "");
        vestingWallet = TajirVestingWallet(payable(address(proxyVest)));
        vestingWallet.initialize(
            beneficiary,
            startTimestamp,
            48 * MONTH,
            12 * MONTH,
            2 * MONTH,
            18,
            admin,
            admin,
            address(0)
        );

        TajirVestingWallet newImplementation = new TajirVestingWallet();

        // Read from the proxy's storage slot before upgrade
        address olderImplementation = address(
            uint160(
                uint256(
                    vm.load(
                        address(vestingWallet),
                        ERC1967Utils.IMPLEMENTATION_SLOT
                    )
                )
            )
        );
        assertNotEq(
            address(newImplementation),
            olderImplementation,
            "New implementation should be different from current"
        );

        vestingWallet.upgradeToAndCall(address(newImplementation), "");

        // Read from the proxy's storage slot after upgrade
        address updatedImplementation = address(
            uint160(
                uint256(
                    vm.load(
                        address(vestingWallet),
                        ERC1967Utils.IMPLEMENTATION_SLOT
                    )
                )
            )
        );

        assertEq(
            updatedImplementation,
            address(newImplementation),
            "Proxy implementation should be updated to new implementation"
        );
        assertNotEq(
            updatedImplementation,
            olderImplementation,
            "Proxy implementation should be different from the old one"
        );
        vm.stopPrank();
    }

    function testUpgradeRevertsIfNotUpgrader() public {
        TajirVestingWallet walletImpl = new TajirVestingWallet();
        ERC1967Proxy proxyVest = new ERC1967Proxy(address(walletImpl), "");
        vestingWallet = TajirVestingWallet(payable(address(proxyVest)));
        vestingWallet.initialize(
            beneficiary,
            startTimestamp,
            48 * MONTH,
            12 * MONTH,
            2 * MONTH,
            18,
            admin,
            admin,
            address(0)
        );

        TajirVestingWallet newImpl = new TajirVestingWallet();
        vm.prank(pauser);
        vm.expectRevert(TajirVestingWallet.NotUpgrader.selector);
        vestingWallet.upgradeToAndCall(address(newImpl), "");
    }

    function test_Initialize_RevertIfAdminZeroAddress() public {
        TajirVestingWallet newWallet = new TajirVestingWallet();
        ERC1967Proxy proxyVest = new ERC1967Proxy(address(newWallet), "");
        vestingWallet = TajirVestingWallet(payable(address(proxyVest)));

        vm.expectRevert(TajirVestingWallet.ZeroAddress.selector);
        vestingWallet.initialize(
            address(0x1),
            uint64(block.timestamp),
            60 days,
            30 days,
            1 days,
            30,
            address(0),
            admin,
            address(0)
        );
    }

    function test_Initialize_RevertIfUpgraderZeroAddress() public {
        TajirVestingWallet newWallet = new TajirVestingWallet();
        ERC1967Proxy proxyVest = new ERC1967Proxy(address(newWallet), "");
        vestingWallet = TajirVestingWallet(payable(address(proxyVest)));

        vm.expectRevert(TajirVestingWallet.ZeroAddress.selector);
        vestingWallet.initialize(
            address(0x1),
            uint64(block.timestamp),
            60 days,
            30 days,
            1 days,
            30,
            admin,
            address(0),
            address(0)
        );
    }

    function testUpgraderGetter() public {
        vestingWallet = _createVestingWallet(
            48 * MONTH,
            12 * MONTH,
            MONTH * 2,
            18
        );
        assertEq(
            vestingWallet.upgrader(),
            admin,
            "upgrader() should return the configured upgrader address"
        );
    }

    function test_OnlyUpgraderCanUpgrade() public {
        address upgraderAddr = vm.addr(99);
        TajirVestingWallet newImpl = new TajirVestingWallet();
        ERC1967Proxy proxyVest = new ERC1967Proxy(address(newImpl), "");
        vestingWallet = TajirVestingWallet(payable(address(proxyVest)));
        vestingWallet.initialize(
            beneficiary,
            uint64(block.timestamp),
            48 * MONTH,
            12 * MONTH,
            2 * MONTH,
            18,
            admin,
            upgraderAddr,
            address(0)
        );

        TajirVestingWallet impl2 = new TajirVestingWallet();
        // Admin cannot upgrade — only the upgrader role can
        vm.prank(admin);
        vm.expectRevert(TajirVestingWallet.NotUpgrader.selector);
        vestingWallet.upgradeToAndCall(address(impl2), "");

        vm.prank(upgraderAddr);
        vestingWallet.upgradeToAndCall(address(impl2), "");
    }

    function test_WithdrawRevertIfToZeroAddress() public {
        vestingWallet = _createVestingWallet(
            48 * MONTH,
            12 * MONTH,
            MONTH * 2,
            18
        );

        vm.expectRevert(TajirVestingWallet.ZeroAddress.selector);
        vm.prank(admin);
        vestingWallet.withdrawUnreleased(address(0), payable(address(0)));
    }

    function test_WithdrawUnreleased_RevertIfAlreadyRevoked() public {
        vestingWallet = _createVestingWallet(
            48 * MONTH,
            12 * MONTH,
            MONTH * 2,
            18
        );

        // Admin revokes the wallet first
        vm.prank(admin);
        vestingWallet.withdrawUnreleased(address(0), payable(admin));

        // Attempt to withdraw again (or revoke again)
        vm.expectRevert(TajirVestingWallet.AlreadyRevoked.selector);
        vm.prank(admin);
        vestingWallet.withdrawUnreleased(address(0), payable(admin));
    }

    function test_WithdrawUnreleased_ERC20() public {
        uint256 amount = 100_000e18;

        vestingWallet = _createErc20VestingWallet(
            address(token),
            48 * MONTH,
            12 * MONTH,
            MONTH * 2,
            18
        );
        token.mint(address(vestingWallet), amount);

        uint256 adminBalanceBefore = token.balanceOf(admin);

        vm.prank(admin);
        vestingWallet.withdrawUnreleased(address(token), payable(admin));

        assertEq(token.balanceOf(admin), adminBalanceBefore + amount);
        assertEq(token.balanceOf(address(vestingWallet)), 0);
    }

    /*//////////////////////////////////////////////////////////////
                           EDGE CASE TESTS
    //////////////////////////////////////////////////////////////*/

    function testSingleTrancheBulletUnlock() public {
        // 12 months cliff, 1 tranche of 12 months
        uint64 cliff = 12 * MONTH;
        uint64 trancheDur = 12 * MONTH;
        uint64 totalTranches = 1;
        uint64 duration = 24 * MONTH;

        vestingWallet = _createVestingWallet(
            duration,
            cliff,
            trancheDur,
            totalTranches
        );

        // At Month 12 (Cliff) -> 0
        vm.warp(startTimestamp + 12 * MONTH);
        assertEq(vestingWallet.releasable(), 0);

        // At Month 24 (End) -> 100%
        vm.warp(startTimestamp + 24 * MONTH);
        assertEq(vestingWallet.releasable(), vestingAmount);
    }

    function testZeroCliffImmediateStart() public {
        // 0 cliff, 12 tranches of 1 month
        uint64 cliff = 0;
        uint64 trancheDur = MONTH;
        uint64 totalTranches = 12;
        uint64 duration = 12 * MONTH;

        vestingWallet = _createVestingWallet(
            duration,
            cliff,
            trancheDur,
            totalTranches
        );

        // Start + 1 day -> 0
        vm.warp(startTimestamp + 1 days);
        assertEq(vestingWallet.releasable(), 0);

        // Month 1 -> 1/12
        vm.warp(startTimestamp + MONTH);
        assertEq(vestingWallet.releasable(), vestingAmount / 12);
    }

    function testFarFutureUnlocks() public {
        uint64 cliff = 12 * MONTH;
        uint64 trancheDur = 2 * MONTH;
        uint64 totalTranches = 18;
        uint64 duration = 48 * MONTH;

        vestingWallet = _createVestingWallet(
            duration,
            cliff,
            trancheDur,
            totalTranches
        );

        // Warp 100 years into the future
        vm.warp(startTimestamp + 100 * 365 days);
        assertEq(vestingWallet.releasable(), vestingAmount);
    }

    function testReleaseEmptyReleasable() public {
        uint64 cliff = 12 * MONTH;
        uint64 trancheDur = 2 * MONTH;
        uint64 totalTranches = 18;
        uint64 duration = 48 * MONTH;

        vestingWallet = _createVestingWallet(
            duration,
            cliff,
            trancheDur,
            totalTranches
        );

        // At month 6, nothing releasable
        vm.warp(startTimestamp + 6 * MONTH);
        assertEq(vestingWallet.releasable(), 0);

        uint256 balBefore = beneficiary.balance;
        vm.prank(beneficiary);
        vestingWallet.release();

        assertEq(beneficiary.balance, balBefore, "Balance should not change");
        assertEq(vestingWallet.released(), 0);
    }
}
