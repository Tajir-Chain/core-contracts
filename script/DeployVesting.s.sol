// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {Config} from "forge-std/Config.sol";
import {console2} from "forge-std/console2.sol";
import {TajirVestingWallet} from "../src/TajirVestingWallet.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title DeployVesting
 * @notice Deployment script for TJR token vesting contracts (650M total supply)
 * @dev Deploys TajirVestingWallet instances per the official tokenomics schedule
 *
 * IMPORTANT: This script uses PLACEHOLDER addresses for development.
 * All addresses marked TODO must be replaced before production deployment.
 *
 * Tokenomics (Total: 650M TJR):
 * | # | Category                         | %   | Amount   | TGE  | Cliff      | Vesting Schedule     | Release Mechanism                |
 * |---|----------------------------------|-----|----------|------|------------|----------------------|----------------------------------|
 * | 1 | Team & Advisors                  | 5%  | 32.5M    | 0%   | 12 months  | 48 months linear     | TajirVestingWallet               |
 * | 2 | Private Round                    | 6%  | 39M      | 10%  | 12 months  | Lump-sum unlock      | Merkle Vesting / Direct          |
 * | 3 | Future Strategic Issuance        | 5%  | 32.5M    | 0%   | Governance | Governance-gated     | TajirTimelock                    |
 * | 4 | Liquidity & Market Operations    | 8%  | 52M      | 100% | —          | Immediate at TGE     | Direct Allocation                |
 * | 5 | Ecosystem Growth                 | 17% | 110.5M   | 5%   | —          | 48 months linear     | TajirVestingWallet               |
 * | 6 | Community Rewards                | 4%  | 26M      | 20%  | —          | Programmatic         | RewardDistributor / Programmatic |
 * | 7 | Loyalty & Legacy Holders Program | 23% | 149.5M   | 0%   | Smart cont | Adaptive (15–30 yrs) | Dedicated Loyalty Vault / SC     |
 * | 8 | Treasury Release                 | 17% | 110.5M   | 0%   | Governance | Governance-gated     | TajirTimelock                    |
 * | 9 | Infrastructure & Network Ops     | 15% | 97.5M    | 0%   | —          | Operational          | TajirTimelock / Operational       |
 *
 * Architecture:
 * - Category 1 (Team & Advisors): TajirVestingWallet (4 per-member wallets, 12mo cliff + 48mo linear)
 * - Category 2 (Private Round):   Merkle Vesting / Direct (10% TGE + 90% 12mo lump-sum)
 * - Category 3 (Future Strategic):TajirTimelock (governance-gated)
 * - Category 4 (Liquidity & Mkt): Direct transfer (100% at TGE)
 * - Category 5 (Ecosystem Growth):TajirVestingWallet (5% TGE + 95% linear over 48mo)
 * - Category 6 (Community Rewards):RewardDistributor (20% TGE + 80% programmatic)
 * - Category 7 (Loyalty & Legacy):Dedicated smart contract (adaptive 15–30 yrs)
 * - Category 8 (Treasury Release):TajirTimelock (governance-gated)
 * - Category 9 (Infrastructure):  TajirTimelock (operational allocations)
 */
contract DeployVesting is Script, Config {
    // ---------------------------------------------------------------------
    // Time constants
    // ---------------------------------------------------------------------
    uint64 constant MONTH = 30 days;
    uint64 constant YEAR = 365 days;

    // ---------------------------------------------------------------------
    // Token amounts (650M total supply)
    // ---------------------------------------------------------------------
    uint256 constant TOTAL_SUPPLY = 650_000_000e18;

    // Category totals
    uint256 constant TEAM_TOTAL = 32_500_000e18; // 5%
    uint256 constant PRIVATE_TOTAL = 39_000_000e18; // 6%
    uint256 constant FUTURE_STRATEGIC_TOTAL = 32_500_000e18; // 5%
    uint256 constant LIQUIDITY_OPERATIONS_TOTAL = 52_000_000e18; // 8%
    uint256 constant ECOSYSTEM_GROWTH_TOTAL = 110_500_000e18; // 17%
    uint256 constant COMMUNITY_REWARDS_TOTAL = 26_000_000e18; // 4%
    uint256 constant LOYALTY_LEGACY_TOTAL = 149_500_000e18; // 23%
    uint256 constant TREASURY_TOTAL = 110_500_000e18; // 17%
    uint256 constant INFRA_TOTAL = 97_500_000e18; // 15%

    // TGE unlock amounts (sent immediately, no vesting)
    uint256 constant PRIVATE_TGE = 3_900_000e18; // 10% of 39M
    uint256 constant LIQUIDITY_OPERATIONS_TGE = 52_000_000e18; // 100% of 52M
    uint256 constant ECOSYSTEM_GROWTH_TGE = 5_525_000e18; // 5% of 110.5M
    uint256 constant COMMUNITY_REWARDS_TGE = 5_200_000e18; // 20% of 26M

    // Vested / Programmatic amounts
    uint256 constant TEAM_VESTED = 32_500_000e18; // 100% (12mo cliff + 48mo linear)
    uint256 constant PRIVATE_VESTED = 35_100_000e18; // 90% (12mo cliff lump-sum)
    uint256 constant ECOSYSTEM_GROWTH_VESTED = 104_975_000e18; // 95% (48mo linear)
    uint256 constant COMMUNITY_REWARDS_PROGRAMMATIC = 20_800_000e18; // 80% (programmatic)

    // ---------------------------------------------------------------------
    // PLACEHOLDER ADDRESSES — TODO: REPLACE BEFORE PRODUCTION
    // ---------------------------------------------------------------------

    // Team & Advisors (4-8 individual wallets, 12mo cliff + 48mo linear)
    // TODO: REPLACE WITH REAL TEAM MEMBER ADDRESSES BEFORE PRODUCTION
    address constant TEAM_MEMBER_1 = 0xAaAAAaaAAAAAAaaAAAaaaaAaAaAAAAaAAaAaAaA1;
    address constant TEAM_MEMBER_2 = 0xAaAaaAAAaAaaAaAaAaaAAaAaAAAAAaAAAaaAaAa2;
    address constant TEAM_MEMBER_3 = 0xaaaaAaAaaAAaAaaaaAaAAAAAaAAAaAaaaAAaAaa3;
    address constant TEAM_MEMBER_4 = 0xAaaaAaaAaAAaaaAaaAAaaAaaAaAaAaAAAAAaaaa4;

    // Private round investors (multiple recipients via Merkle in TajirVesting)
    // TODO: REPLACE WITH MERKLE ROOT OF PRIVATE ROUND ALLOCATIONS
    bytes32 constant PRIVATE_ROUND_MERKLE_ROOT = bytes32(0);

    // Future Strategic Issuance Timelock (governance-gated)
    // TODO: REPLACE WITH DEPLOYED TajirTimelock ADDRESS
    address constant FUTURE_STRATEGIC_TIMELOCK =
        0x1111111111111111111111111111111111111111;

    // Liquidity & Market Operations partner (single recipient, 100% TGE)
    // TODO: REPLACE WITH REAL MARKET MAKING / LIQUIDITY MULTISIG
    address constant LIQUIDITY_OPERATIONS_RECIPIENT =
        0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC;

    // Ecosystem Growth multisig (5% TGE direct + 95% vested)
    // TODO: REPLACE WITH REAL ECOSYSTEM MULTISIG
    address constant ECOSYSTEM_MULTISIG =
        0xDDdDddDdDdddDDddDDddDDDDdDdDDdDDdDDDDDDd;

    // Community Rewards / RewardDistributor (20% TGE direct + 80% programmatic)
    // TODO: REPLACE WITH DEPLOYED RewardDistributor ADDRESS
    address constant COMMUNITY_REWARD_DISTRIBUTOR =
        0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    // Loyalty & Legacy Holders Vault (smart contract adaptive distribution)
    // TODO: REPLACE WITH DEPLOYED LoyaltyVault ADDRESS
    address constant LOYALTY_VAULT =
        0x2222222222222222222222222222222222222222;

    // Treasury Release timelock (deployed via Deploy.s.sol)
    // TODO: REPLACE WITH DEPLOYED TajirTimelock ADDRESS
    address constant TREASURY_TIMELOCK =
        0xffffFFFfFFffffffffffffffFfFFFfffFFFfFFfE;

    // Infrastructure & Network Ops timelock (separate from treasury)
    // TODO: REPLACE WITH DEPLOYED Infra TajirTimelock ADDRESS
    address constant INFRA_TIMELOCK =
        0xfFfFFffFffffFFffFffFFFFFFfFFFfFfFFfFfFfD;

    // ---------------------------------------------------------------------
    // Vesting config struct
    // ---------------------------------------------------------------------
    struct VestingConfig {
        address beneficiary;
        uint256 amount;
        uint64 cliff;
        uint64 duration;
        string category;
        uint64 trancheDuration;
        uint64 totalTranches;
    }

    // ---------------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------------
    error DeployVesting__InvalidAddress(address _address);

    // ---------------------------------------------------------------------
    // Run
    // ---------------------------------------------------------------------
    /// @dev Extracted so the main loop stays under the EVM stack limit.
    function _deployWallet(
        VestingConfig memory cfg,
        uint64 startTimestamp,
        address admin,
        address upgrader
    ) internal returns (TajirVestingWallet wallet) {
        TajirVestingWallet impl = new TajirVestingWallet();
        bytes memory initData = abi.encodeWithSignature(
            "initialize(address,uint64,uint64,uint64,uint64,uint64,address,address)",
            cfg.beneficiary,
            startTimestamp,
            cfg.duration,
            cfg.cliff,
            cfg.trancheDuration,
            cfg.totalTranches,
            admin,
            upgrader
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        wallet = TajirVestingWallet(payable(address(proxy)));
    }

    function run() public returns (TajirVestingWallet[] memory) {
        // Load configuration from TOML file (with write-back enabled)
        _loadConfig("./deployments.toml", true);

        address admin = config.get("defaultAdmin").toAddress();
        // Separate upgrade authority — keeping revoke (admin) and upgrade
        // (upgrader) under different keys avoids a single point of failure.
        // Convention: use the system timelock so upgrades go through
        // governance, while admin remains the multisig that can revoke.
        address upgrader = config.get("tajir_timelock").toAddress();

        if (admin == address(0)) revert DeployVesting__InvalidAddress(admin);
        if (upgrader == address(0)) {
            revert DeployVesting__InvalidAddress(upgrader);
        }

        uint64 startTimestamp = uint64(block.timestamp);

        VestingConfig[] memory configs = getVestingConfigs();

        vm.startBroadcast();

        TajirVestingWallet[] memory wallets = new TajirVestingWallet[](
            configs.length
        );

        for (uint256 i = 0; i < configs.length; i++) {
            wallets[i] = _deployWallet(
                configs[i],
                startTimestamp,
                admin,
                upgrader
            );
            VestingConfig memory cfg = configs[i];

            console2.log("Deployed", cfg.category, "vesting wallet:");
            console2.log("  Address:    ", address(wallets[i]));
            console2.log("  Beneficiary:", cfg.beneficiary);
            console2.log("  Amount:     ", cfg.amount / 1e18, "TJR");
            console2.log("  Cliff (mo): ", cfg.cliff / MONTH);
            console2.log("  Duration:   ", cfg.duration / MONTH, "months");
            console2.log("");
        }

        vm.stopBroadcast();

        // Verify total tokenomics distribution
        uint256 total = TEAM_TOTAL +
            PRIVATE_TOTAL +
            FUTURE_STRATEGIC_TOTAL +
            LIQUIDITY_OPERATIONS_TOTAL +
            ECOSYSTEM_GROWTH_TOTAL +
            COMMUNITY_REWARDS_TOTAL +
            LOYALTY_LEGACY_TOTAL +
            TREASURY_TOTAL +
            INFRA_TOTAL;
        require(total == TOTAL_SUPPLY, "Allocation mismatch");

        console2.log("All vesting wallets deployed.");
        console2.log(
            "Total tokenomics:",
            total / 1e18,
            "TJR (must equal 650M)"
        );

        return wallets;
    }

    // ---------------------------------------------------------------------
    // Vesting configurations
    // ---------------------------------------------------------------------
    // Only deploys TajirVestingWallet instances. The other categories are
    // handled separately:
    //   - Private: deploy TajirVesting with merkle root via DeployMerkleVesting.s.sol
    //   - Liquidity & Market Operations: direct transfer (no contract)
    //   - Future Strategic / Treasury / Infra: TajirTimelock contracts
    //   - Loyalty & Legacy: dedicated adaptive distribution smart contract
    //   - Community: programmatic distribution via RewardDistributor
    // ---------------------------------------------------------------------
    function getVestingConfigs()
        internal
        pure
        returns (VestingConfig[] memory)
    {
        VestingConfig[] memory configs = new VestingConfig[](5);

        // Each team member gets equal share (32.5M / 4 = 8.125M each for 4 members)
        // 12 months cliff followed by 48 months linear unlock (total duration = 60 months)
        // (totalTranches * trancheDuration) + cliff = (48 * 1 mo) + 12 mo = 60 mo
        uint256 teamMemberAmount = TEAM_TOTAL / 4;

        configs[0] = VestingConfig({
            beneficiary: TEAM_MEMBER_1,
            amount: teamMemberAmount,
            cliff: 12 * MONTH,
            duration: 60 * MONTH,
            category: "Team-1",
            trancheDuration: 1 * MONTH,
            totalTranches: 48
        });

        configs[1] = VestingConfig({
            beneficiary: TEAM_MEMBER_2,
            amount: teamMemberAmount,
            cliff: 12 * MONTH,
            duration: 60 * MONTH,
            category: "Team-2",
            trancheDuration: 1 * MONTH,
            totalTranches: 48
        });

        configs[2] = VestingConfig({
            beneficiary: TEAM_MEMBER_3,
            amount: teamMemberAmount,
            cliff: 12 * MONTH,
            duration: 60 * MONTH,
            category: "Team-3",
            trancheDuration: 1 * MONTH,
            totalTranches: 48
        });

        configs[3] = VestingConfig({
            beneficiary: TEAM_MEMBER_4,
            amount: teamMemberAmount,
            cliff: 12 * MONTH,
            duration: 60 * MONTH,
            category: "Team-4",
            trancheDuration: 1 * MONTH,
            totalTranches: 48
        });

        // Ecosystem Growth vesting (95% over 48 months, no cliff)
        // (totalTranches * trancheDuration) + cliff = (48 * 1 mo) + 0 mo = 48 mo
        configs[4] = VestingConfig({
            beneficiary: ECOSYSTEM_MULTISIG,
            amount: ECOSYSTEM_GROWTH_VESTED,
            cliff: 0,
            duration: 48 * MONTH,
            category: "Ecosystem",
            trancheDuration: 1 * MONTH,
            totalTranches: 48
        });

        return configs;
    }
}
