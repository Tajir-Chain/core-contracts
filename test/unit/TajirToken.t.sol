// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Setup} from "../Setup.t.sol";
import {console} from "forge-std/Test.sol";

import {TajirToken} from "src/token/TajirToken.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract TajirTokenTest is Setup {
    TajirToken public tajirToken;

    function setUp() public override {
        super.setUp();

        vm.startPrank(admin);

        TajirToken tajirTokenImpl = new TajirToken();
        ERC1967Proxy proxy = new ERC1967Proxy(address(tajirTokenImpl), "");
        tajirToken = TajirToken(address(proxy));

        // Initialize TajirToken with 650M initial supply to admin
        tajirToken.initialize(
            "Tajir Token",
            "TJR",
            650_000_000,
            admin, // initial holder
            admin // upgrader
        );

        vm.stopPrank();
    }

    // =========================================================
    //  Non-Upgradeability Tests
    // =========================================================

    /// @notice Proves that the UPGRADER_ROLE holder (admin) cannot upgrade the proxy.
    ///         _authorizeUpgrade unconditionally reverts, so upgradeToAndCall must revert
    ///         with the hardcoded "Not Upgradeable Anymore!" message, regardless of the caller's role.
    function testUpgradeRevertsForUpgraderRole() public {
        // Deploy a new implementation to use as the "upgrade target"
        TajirToken newImpl = new TajirToken();

        vm.prank(admin); // admin holds UPGRADER_ROLE
        vm.expectRevert(bytes("Not Upgradeable Anymore!"));
        tajirToken.upgradeToAndCall(address(newImpl), "");
    }

    /// @notice Proves that a non-privileged, random address also cannot upgrade the proxy.
    ///         Even though _authorizeUpgrade has `onlyRole(UPGRADER_ROLE)`, the unconditional
    ///         revert() fires first (it's the body of the function), making the outcome
    ///         identical regardless of caller.
    function testUpgradeRevertsForNonAdmin() public {
        TajirToken newImpl = new TajirToken();
        address randomUser = makeAddr("randomUser");

        vm.prank(randomUser);
        // The revert("Not Upgradeable Anymore!") fires before any role check body logic,
        // but the onlyRole modifier will revert FIRST for unauthorised callers.
        // Either way the call reverts — the proxy is still not upgradeable.
        vm.expectRevert(); // accept any revert (role check or custom message)
        tajirToken.upgradeToAndCall(address(newImpl), "");
    }

    /// @notice Proves that even with calldata (init call), the upgrade is blocked.
    ///         This tests the upgradeToAndCall(addr, data) variant used when an
    ///         initializer needs to run on the new implementation.
    function testUpgradeWithCalldataAlsoReverts() public {
        TajirToken newImpl = new TajirToken();

        // Craft calldata for a hypothetical re-initializer
        bytes memory initCall = abi.encodeWithSignature(
            "initialize(string,string,uint256,address,address)",
            "Tajir Token",
            "TJR",
            650_000_000,
            admin,
            admin
        );

        vm.prank(admin);
        vm.expectRevert(bytes("Not Upgradeable Anymore!"));
        tajirToken.upgradeToAndCall(address(newImpl), initCall);
    }

    /// @notice Proves the implementation address in the proxy slot never changed
    ///         after a failed upgrade attempt.
    function testImplementationSlotUnchangedAfterFailedUpgrade() public {
        // Record current implementation address via ERC1967 slot
        bytes32 implSlot = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
        bytes32 beforeUpgrade = vm.load(address(tajirToken), implSlot);

        TajirToken newImpl = new TajirToken();

        vm.prank(admin);
        vm.expectRevert(bytes("Not Upgradeable Anymore!"));
        tajirToken.upgradeToAndCall(address(newImpl), "");

        bytes32 afterFailedUpgrade = vm.load(address(tajirToken), implSlot);

        // Slot must be identical — the revert rolled back any state change
        assertEq(
            beforeUpgrade,
            afterFailedUpgrade,
            "Implementation slot must not change after a failed upgrade"
        );
    }

    function testBurnDecreasesTotalSupply() public {
        uint256 burnAmount = 100 * 10 ** 18;

        uint256 initialSupply = tajirToken.totalSupply();
        uint256 initialBalance = tajirToken.balanceOf(admin);

        // Burn tokens from admin
        vm.prank(admin);
        tajirToken.burn(burnAmount);

        uint256 finalSupply = tajirToken.totalSupply();
        uint256 finalBalance = tajirToken.balanceOf(admin);

        console.log("initialSupply", initialSupply / 10 ** 18);
        console.log("initialBalance", initialBalance / 10 ** 18);
        console.log("finalSupply", finalSupply / 10 ** 18);
        console.log("finalBalance", finalBalance / 10 ** 18);

        // Assert that both the total supply and the admin's balance decreased by the burn amount
        assertEq(
            finalSupply,
            initialSupply - burnAmount,
            "Total supply should decrease by burn amount"
        );
        assertEq(
            finalBalance,
            initialBalance - burnAmount,
            "Admin balance should decrease by burn amount"
        );
    }
}
