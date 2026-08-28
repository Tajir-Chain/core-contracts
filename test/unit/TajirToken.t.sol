// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/Test.sol";

import {TajirToken} from "src/token/TajirToken.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract TajirTokenTest is Test {
    address public admin;

    TajirToken public tajirToken;

    function setUp() public {
        admin = vm.addr(1);

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
