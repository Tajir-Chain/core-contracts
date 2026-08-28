// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {Config} from "forge-std/Config.sol";
import {console2} from "forge-std/console2.sol";
import {TajirToken} from "../src/token/TajirToken.sol";
import {TajirTokenProxy} from "../src/token/TajirTokenProxy.sol";

/**
 * @title DeployToken
 * @notice Deployment script for the TajirToken ERC-20 genesis deployment
 * @dev Deploys TajirToken implementation + TajirTokenProxy, then initialises with
 *      the full 650,000,000 TJR supply minted to the Bootstrap Safe multisig.
 *
 * IMPORTANT: This script uses PLACEHOLDER addresses.
 * All addresses marked TODO must be replaced before production deployment.
 *
 * Genesis Deployment Steps:
 * 1. Deploy TajirToken implementation (logic contract)
 * 2. Deploy TajirTokenProxy (ERC-1967) pointed at the implementation
 * 3. Initialise: mint 650M TJR to BOOTSTRAP_SAFE; grant UPGRADER_ROLE to UPGRADER_ADDRESS
 * 4. Verify on Etherscan (--verify flag)
 * 5. Log addresses to deployments.toml for downstream scripts (DeployVesting.s.sol)
 */
contract DeployToken is Script, Config {
    // -------------------------------------------------------------------------
    // Genesis supply
    // -------------------------------------------------------------------------
    uint256 constant TOTAL_SUPPLY = 650_000_000; // passed without decimals; TajirToken scales internally

    // -------------------------------------------------------------------------
    // PLACEHOLDER ADDRESSES — TODO: REPLACE BEFORE PRODUCTION
    // -------------------------------------------------------------------------

    /// @dev Bootstrap Safe / Multisig that receives the entire genesis supply
    /// TODO: REPLACE WITH DEPLOYED GNOSIS SAFE ADDRESS
    address constant BOOTSTRAP_SAFE =
        0xBBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB;

    /// @dev Address granted DEFAULT_ADMIN_ROLE + UPGRADER_ROLE on the token
    /// Recommended: deploy a TajirTimelock first and use its address here
    /// TODO: REPLACE WITH GOVERNANCE TIMELOCK OR BOOTSTRAP SAFE
    address constant UPGRADER_ADDRESS =
        0xBBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB;

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------
    error DeployToken__InvalidAddress(address _address);
    error DeployToken__ZeroSupply();

    // -------------------------------------------------------------------------
    // Run
    // -------------------------------------------------------------------------
    function run() public returns (TajirToken token, TajirTokenProxy proxy) {
        // Optionally load overrides from TOML (addresses can override constants)
        _loadConfig("./deployments.toml", true);

        address bootstrapSafe = BOOTSTRAP_SAFE;
        address upgrader = UPGRADER_ADDRESS;

        // Allow config overrides
        try config.get("bootstrap_safe").toAddress() returns (address _safe) {
            if (_safe != address(0)) bootstrapSafe = _safe;
        } catch {}
        try config.get("upgrader").toAddress() returns (address _upgrader) {
            if (_upgrader != address(0)) upgrader = _upgrader;
        } catch {}

        if (bootstrapSafe == address(0)) revert DeployToken__InvalidAddress(bootstrapSafe);
        if (upgrader == address(0)) revert DeployToken__InvalidAddress(upgrader);

        vm.startBroadcast();

        // 1. Deploy implementation (logic) contract
        TajirToken impl = new TajirToken();

        // 2. Deploy proxy (no data — initialise in step 3 via proxy call)
        proxy = new TajirTokenProxy(address(impl), "");
        token = TajirToken(address(proxy));

        // 3. Initialise — mints 650M TJR to bootstrapSafe; grants UPGRADER_ROLE to upgrader
        token.initialize(
            "Tajir Token",
            "TJR",
            TOTAL_SUPPLY,
            bootstrapSafe,
            upgrader
        );

        vm.stopBroadcast();

        // -------------------------------------------------------------------------
        // Log output
        // -------------------------------------------------------------------------
        console2.log("=== TajirToken Genesis Deployment ===");
        console2.log("Implementation:    ", address(impl));
        console2.log("Proxy (TJR token): ", address(proxy));
        console2.log("Bootstrap Safe:    ", bootstrapSafe);
        console2.log("Upgrader:          ", upgrader);
        console2.log("Total Supply:      ", token.totalSupply() / 1e18, "TJR");
        console2.log("Bootstrap Balance: ", token.balanceOf(bootstrapSafe) / 1e18, "TJR");
        console2.log("=====================================");

        // Verify invariants
        require(
            token.totalSupply() == TOTAL_SUPPLY * 1e18,
            "Supply mismatch"
        );
        require(
            token.balanceOf(bootstrapSafe) == TOTAL_SUPPLY * 1e18,
            "Bootstrap balance mismatch"
        );
    }
}
