// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {TajirVestingWallet} from "src/TajirVestingWallet.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract TajirVestingWalletFuzz is Test {
    TajirVestingWallet wallet;

    address admin = vm.addr(1);
    address beneficiary = vm.addr(2);

    uint64 constant START = 1_000_000;

    function setUp() public {}

    function _deploy(
        uint64 cliff,
        uint64 tDur,
        uint64 tCount
    ) internal returns (TajirVestingWallet) {
        TajirVestingWallet impl = new TajirVestingWallet();
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), "");
        TajirVestingWallet v = TajirVestingWallet(payable(address(proxy)));
        v.initialize(
            beneficiary,
            START,
            (tCount * tDur) + cliff,
            cliff,
            tDur,
            tCount,
            admin,
            admin
        );
        return v;
    }

    function testFuzz_VestedAmount(
        uint64 cliff,
        uint64 tDur,
        uint64 tCount,
        uint256 alloc,
        uint64 warp
    ) public {
        cliff = uint64(bound(cliff, 0, 365 days));
        tDur = uint64(bound(tDur, 1, 30 days));
        tCount = uint64(bound(tCount, 1, 100));
        alloc = bound(alloc, 1, 1e36);
        warp = uint64(bound(warp, START, START + 365 days * 20));

        wallet = _deploy(cliff, tDur, tCount);
        vm.deal(address(wallet), alloc);

        uint256 vested = wallet.vestedAmount(warp);

        assertLe(vested, alloc);
        if (warp < wallet.cliff()) assertEq(vested, 0);
        else if (warp >= wallet.end()) assertEq(vested, alloc);
        else
            assertEq(
                vested,
                (alloc * ((warp - wallet.cliff()) / tDur)) / tCount
            );
    }

    function testFuzz_WithdrawUnreleased(
        uint64 cliff,
        uint64 tDur,
        uint64 tCount,
        uint256 alloc,
        uint64 warp
    ) public {
        cliff = uint64(bound(cliff, 0, 365 days));
        tDur = uint64(bound(tDur, 1, 30 days));
        tCount = uint64(bound(tCount, 1, 100));
        alloc = bound(alloc, 1e18, 1e30);
        warp = uint64(bound(warp, START, START + (tCount * tDur) + cliff - 1));

        wallet = _deploy(cliff, tDur, tCount);
        vm.deal(address(wallet), alloc);
        vm.warp(warp);

        uint256 claimable = wallet.vestedAmount(warp) -
            wallet.released(address(0));
        if (alloc <= claimable) return;

        uint256 before = admin.balance;
        vm.prank(admin);
        wallet.withdrawUnreleased(address(0), payable(admin));

        assertEq(admin.balance, before + (alloc - claimable));
        assertEq(address(wallet).balance, claimable);
    }

    function testFuzz_Security(address attacker, uint256 amount) public {
        vm.assume(attacker != admin && attacker != address(0));
        wallet = _deploy(0, 1, 1);
        vm.deal(address(wallet), amount);
        vm.prank(attacker);
        vm.expectRevert(TajirVestingWallet.NotAdmin.selector);
        wallet.withdrawUnreleased(address(0), payable(attacker));
    }
}
