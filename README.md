<div align="center">

<br/>

# Tajir Chain · Core Contracts

**The foundational smart contracts powering the Tajir Chain ecosystem.**  
L1 bridged gas token (`TJR`), ERC-1967 UUPS upgradeable proxies, and cliff-based tranche vesting infrastructure.

<br/>

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)
[![Solidity ≥ 0.8.27](https://img.shields.io/badge/Solidity-%E2%89%A50.8.27-363636?logo=solidity)](https://soliditylang.org/)
[![Built with Foundry](https://img.shields.io/badge/Built%20with-Foundry-FF4F00?logo=ethereum)](https://book.getfoundry.sh/)
[![OpenZeppelin v5.5.0](https://img.shields.io/badge/OpenZeppelin-v5.5.0-4E5EE4?logo=openzeppelin)](https://openzeppelin.com/)
[![EVM: Cancun](https://img.shields.io/badge/EVM-Cancun-black)](https://ethereum.org/)
[![ERC-7201 Storage](https://img.shields.io/badge/ERC--7201-Namespaced%20Storage-success)](https://eips.ethereum.org/EIPS/eip-7201)

<br/>

[**Documentation**](https://docs.tajirchain.com/) &nbsp;·&nbsp; [**Security Policy**](./SECURITY.md) &nbsp;·&nbsp; [**Report a Bug**](../../issues)

<br/>

---

</div>

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Key Features](#key-features)
4. [Smart Contracts](#smart-contracts)
5. [Tokenomics & Vesting Schedule](#tokenomics--vesting-schedule)
6. [Technology Stack](#technology-stack)
7. [Getting Started](#getting-started)
   - [Prerequisites](#prerequisites)
   - [Installation & Setup](#installation--setup)
   - [Environment Configuration](#environment-configuration)
   - [Available Foundry Commands](#available-foundry-commands)
   - [Build & Compilation](#build--compilation)
   - [Running Tests & Fuzzing](#running-tests--fuzzing)
   - [Static Analysis & Formatting](#static-analysis--formatting)
8. [Deployment & Verification](#deployment--verification)
   - [Local Simulation (Anvil)](#local-simulation-anvil)
   - [Testnet / Mainnet Deployment](#testnet--mainnet-deployment)
9. [Security & Storage Safety](#security--storage-safety)
10. [Project Structure](#project-structure)
11. [Contributing](#contributing)
12. [Security](#security)
13. [License](#license)

---

## Overview

**Tajir Chain Core Contracts** contains the canonical Layer 1 (L1) smart contracts, tokenomics infrastructure, and deployment scripts for **Tajir Chain** — an Ethereum-compatible Layer 2 zkEVM rollup network.

This repository implements:

- **`TajirToken` (`TJR`)**: The official fixed-supply (650,000,000 $TJR) ERC-20 token minted and held on Ethereum L1, locked in the Polygon zkEVM bridge contract, and minted natively on Tajir Chain L2 to serve as the native gas asset.
- **`TajirVestingWallet`**: A modular, cliff-based, tranche-unlocked vesting contract engineered with OpenZeppelin v5.5.0 and ERC-7201 namespaced storage.
- **Automated Deployment & Verification Scripts**: Foundry scripts facilitating deterministic proxy deployments, role configurations, and schedule parameterizations across testnet and mainnet environments.

> **Who is this for?**  
> This repository is intended for **smart contract engineers**, **security auditors**, **node operators**, **ecosystem contributors**, and **institutional stakeholders** seeking to inspect, test, deploy, or integrate with the core economic layer of Tajir Chain.

---

## Architecture

```
                                  ┌────────────────────────────────┐
                                  │       Tajir Governance         │
                                  │    (Multisig / Timelock)       │
                                  └───────────────┬────────────────┘
                                                  │
                      ┌───────────────────────────┴───────────────────────────┐
                      │                                                       │
                      ▼ (Admin / Upgrader)                                    ▼ (Admin / Upgrader)
        ┌───────────────────────────┐                           ┌───────────────────────────┐
        │      ERC-1967 Proxy       │                           │      ERC-1967 Proxy       │
        │    (TajirTokenProxy)      │                           │   (Vesting Instances)     │
        └─────────────┬─────────────┘                           └─────────────┬─────────────┘
                      │ delegates                                             │ delegates
                      ▼                                                       ▼
        ┌───────────────────────────┐                           ┌───────────────────────────┐
        │      TajirToken (L1)      │                           │    TajirVestingWallet     │
        │  • Fixed 650M Supply      │                           │  • ERC-7201 Storage       │
        │  • EIP-2612 Permit        │ ─────── Funds Vesting ───►│  • Cliff + Tranches       │
        │  • UUPS Upgradeable       │                           │  • Revocation Protection  │
        │  • Burnable               │                           │  • Linear Unlock          │
        └─────────────┬─────────────┘                           └─────────────┬─────────────┘
                      │                                                       │
                      ▼ Locked on L1 Deposit                                  ▼ Claimed by
        ┌───────────────────────────┐                           ┌───────────────────────────┐
        │      L1 Bridge & PoE      │                           │        Beneficiary        │
        │  (Polygon zkEVM Bridge)   │                           │     (Investors / Team)    │
        └─────────────┬─────────────┘                           └───────────────────────────┘
                      │
                      │ ZK Merkle Proofs
                      ▼
        ┌───────────────────────────┐
        │     Tajir Chain (L2)      │
        │  (Native Gas Token: TJR)  │
        └───────────────────────────┘
```

**Token Lifecycle & Bridging (L1 → L2):**

1. **Genesis Mint:** `TajirToken` is deployed behind an ERC-1967 proxy; 650,000,000 $TJR is minted once at initialization to the Bootstrap Safe multisig.
2. **Vesting Allocation:** Bootstrap Safe funds `TajirVestingWallet` instances corresponding to tokenomics allocations.
3. **Bridge Deposit:** Tokens deposited to the Polygon zkEVM Bridge contract on Ethereum L1 emit a `BridgeEvent` and are locked in escrow.
4. **ZK Proof Settlement:** The bridge operator validates the batch with ZK Merkle proofs.
5. **L2 Native Gas:** Equivalent $TJR is minted/released on Tajir Chain L2 to fund network transactions.

---

## Key Features

| Feature                              | Description                                                                                                         |
| :----------------------------------- | :------------------------------------------------------------------------------------------------------------------ |
| 🪙 **Fixed-Supply Native Gas Token** | Strict 650,000,000 $TJR total supply with zero runtime minting surface.                                             |
| 🔐 **ERC-7201 Namespaced Storage**   | Custom storage slot hashing (`tajir.storage.TajirVestingWallet`) prevents storage collisions during proxy upgrades. |
| ⏳ **Cliff & Tranche Schedules**     | Configurable lockup cliff periods followed by $N$ equal tranche installments.                                       |
| 🛡️ **Role Segregation**              | Strict separation between administrative operations (`admin`) and upgrade privileges (`upgrader`).                  |
| 🔏 **EIP-2612 Permit Approvals**     | Gasless signature-based token approvals via cryptographic signatures.                                               |
| 🧱 **ERC-1967 UUPS Proxies**         | Gas-efficient upgradeable proxies retaining contract state across implementation upgrades.                          |
| 🧪 **Fuzz & Invariant Tested**       | Thoroughly validated through unit, fuzz (256+ runs), and invariant testing suites in Foundry.                       |
| 🚀 **Deterministic Deployment**      | Automated Foundry scripts with automated Etherscan verification and JSON artifact logging.                          |

---

## Smart Contracts

| Contract                 | Location                                                           | Standard / Pattern                      | Description                                                                                               |
| :----------------------- | :----------------------------------------------------------------- | :-------------------------------------- | :-------------------------------------------------------------------------------------------------------- |
| **`TajirToken`**         | [`src/token/TajirToken.sol`](./src/token/TajirToken.sol)           | ERC-20, ERC-2612, ERC-20 Burnable, UUPS | 650M fixed-supply token; minted at initialization to bootstrap treasury; upgradeable via `UPGRADER_ROLE`. |
| **`TajirTokenProxy`**    | [`src/token/TajirTokenProxy.sol`](./src/token/TajirTokenProxy.sol) | ERC-1967                                | Transparent ERC-1967 proxy delegating to the `TajirToken` implementation contract.                        |
| **`TajirVestingWallet`** | [`src/TajirVestingWallet.sol`](./src/TajirVestingWallet.sol)       | ERC-7201, UUPS, Cliff Vesting           | Minimalist cliff + tranche vesting contract with linear installments and separated admin/upgrader keys.   |

---

## Tokenomics & Vesting Schedule

The total genesis supply of **Tajir Token (`TJR`)** is fixed at **650,000,000 TJR** (18 decimals):

| # | Allocation Category | % of Total | Amount (`TJR`) | TGE Release | Cliff Duration | Vesting Schedule | Release Mechanism |
| :-: | :--- | :-: | :-: | :-: | :-: | :-: | :--- |
| **1** | **Team & Advisors** | 5% | 32,500,000 | 0% | 12 months | 48 months linear | `TajirVestingWallet` |
| **2** | **Private Round** | 6% | 39,000,000 | 10% | 12 months | Lump-sum unlock | Merkle Vesting / Direct |
| **3** | **Future Strategic Issuance** | 5% | 32,500,000 | 0% | Governance | Governance-gated | `TajirTimelock` |
| **4** | **Liquidity & Market Operations** | 8% | 52,000,000 | 100% | — | Immediate at TGE | Direct Allocation |
| **5** | **Ecosystem Growth** | 17% | 110,500,000 | 5% | — | 48 months linear | `TajirVestingWallet` |
| **6** | **Community Rewards** | 4% | 26,000,000 | 20% | — | Programmatic | `RewardDistributor` / Direct |
| **7** | **Loyalty & Legacy Holders Program** | 23% | 149,500,000 | 0% | Smart contract | Adaptive (15–30 yrs) | Dedicated Smart Contract |
| **8** | **Treasury Release** | 17% | 110,500,000 | 0% | Governance | Governance-gated | `TajirTimelock` |
| **9** | **Infrastructure & Network Ops** | 15% | 97,500,000 | 0% | — | Operational | `TajirTimelock` / Operational |

---

## Technology Stack

| Layer                    | Technology                                                        | Version / Standard    |
| :----------------------- | :---------------------------------------------------------------- | :-------------------- |
| **Language**             | [Solidity](https://soliditylang.org/)                             | `^0.8.27`             |
| **Framework**            | [Foundry](https://book.getfoundry.sh/) (`forge`, `cast`, `anvil`) | Latest                |
| **EVM Target**           | Ethereum Cancun                                                   | `cancun`              |
| **Token Standards**      | ERC-20, ERC-2612 (Permit), ERC-5267                               | OpenZeppelin v5.5.0   |
| **Upgrade Standard**     | ERC-1967 Proxy, UUPS (Universal Upgradeable Proxy Standard)       | OpenZeppelin v5.5.0   |
| **Storage Layout**       | ERC-7201 Namespaced Storage                                       | OpenZeppelin v5.5.0   |
| **Base Libraries**       | OpenZeppelin Contracts & Contracts Upgradeable                    | `v5.5.0`              |
| **Testing Toolkit**      | Forge Standard Library (`forge-std`)                              | `v1.9.5`              |
| **Linting & Formatting** | Forge Fmt + Solhint                                               | `solhint:recommended` |

---

## Getting Started

### Prerequisites

| Requirement                            | Minimum Version | Installation Command                              |
| :------------------------------------- | :-------------- | :------------------------------------------------ |
| [Git](https://git-scm.com/)            | Latest          | OS Package Manager                                |
| [Foundry](https://book.getfoundry.sh/) | Latest          | `curl -L https://foundry.sh \| bash && foundryup` |

### Installation & Setup

1. **Clone the repository with submodules**:

   ```bash
   git clone --recurse-submodules https://github.com/Tajir-Chain/core-contracts.git
   cd core-contracts
   ```

2. **If cloned without `--recurse-submodules`, initialize dependencies**:
   ```bash
   git submodule update --init --recursive
   ```

### Environment Configuration

Create a `.env` file in the root directory based on required variables:

```bash
cp .env.example .env
```

#### Supported Environment Variables

| Variable                | Description                                     | Example                              |
| :---------------------- | :---------------------------------------------- | :----------------------------------- |
| `SEPOLIA_RPC_URL`       | Ethereum Sepolia JSON-RPC endpoint              | `https://rpc.sepolia.org`            |
| `MAINNET_RPC_URL`       | Ethereum Mainnet JSON-RPC endpoint              | `https://eth.llamarpc.com`           |
| `TAJIR_TESTNET_RPC_URL` | Tajir Chain Testnet JSON-RPC endpoint           | `https://rpc.testnet.tajirchain.com` |
| `PRIVATE_KEY`           | Deployer private key (local/testnet only)       | `0x...`                              |
| `ETHERSCAN_API_KEY`     | Etherscan API key for contract verification     | `AB12...`                            |
| `BOOTSTRAP_SAFE`        | Initial token recipient Safe / Multisig address | `0x...`                              |
| `ADMIN_ADDRESS`         | Administrator key for vesting revocation        | `0x...`                              |
| `UPGRADER_ADDRESS`      | Upgrader key for UUPS implementation upgrades   | `0x...`                              |

### Available Foundry Commands

| Command                               | Description                                           |
| :------------------------------------ | :---------------------------------------------------- |
| `forge build`                         | Compile smart contracts and generate ABI artifacts    |
| `forge test`                          | Run the complete unit and fuzz test suite             |
| `forge test -vvv`                     | Run tests with detailed call traces                   |
| `forge test --match-path test/fuzz/*` | Run property-based fuzz tests exclusively             |
| `forge snapshot`                      | Generate gas usage snapshot reports (`.gas-snapshot`) |
| `forge fmt --check`                   | Verify compliance with Solidity formatting standards  |
| `forge fmt`                           | Auto-format all Solidity source and test files        |
| `forge clean`                         | Remove compiler artifacts and cache                   |

### Build & Compilation

Compile the smart contracts with the optimizer enabled (200 runs):

```bash
forge build
```

### Running Tests & Fuzzing

Execute unit tests, fuzz tests, and invariant checks:

```bash
# Run entire test suite
forge test

# Run tests with stack traces for failed assertions
forge test -vvv

# Run fuzz tests with verbosity
forge test --match-path test/fuzz/* -vvv

# Generate gas consumption report
forge snapshot
```

### Static Analysis & Formatting

Format the codebase and check linting rules:

```bash
# Check code formatting
forge fmt --check

# Format code according to foundry.toml rules
forge fmt
```

---

## Deployment & Verification

### Local Simulation (Anvil)

Simulate contract deployments against a local Anvil node:

```bash
# 1. Start local node
anvil

# 2. Run deployment script locally
forge script script/DeployVesting.s.sol:DeployVesting \
  --rpc-url http://localhost:8545 \
  --broadcast
```

### Testnet / Mainnet Deployment

Deploy to Sepolia testnet or Ethereum Mainnet with automated Etherscan verification:

```bash
# Sepolia Testnet Deployment
forge script script/DeployVesting.s.sol:DeployVesting \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY

# Ethereum Mainnet Deployment (Hardware Wallet / Keystore Recommended)
forge script script/DeployVesting.s.sol:DeployVesting \
  --rpc-url $MAINNET_RPC_URL \
  --account <keystore_account_name> \
  --sender <sender_address> \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

---

## Security & Storage Safety

- **ERC-7201 Namespaced Storage Layout:**  
  `TajirVestingWallet` stores state variables in a designated storage slot calculated via:

  ```solidity
  keccak256(abi.encode(uint256(keccak256("tajir.storage.TajirVestingWallet")) - 1)) & ~bytes32(uint256(0xff))
  ```

  This guarantees that future implementation upgrades can introduce new state variables without causing storage collisions with base OpenZeppelin contracts.

- **Dual-Key Governance & Segregation of Duties:**  
  The revocation authority (`admin`) and the upgrade authorization (`upgrader`) are kept under separate keys. This eliminates single-key takeover risks where a compromised key could both revoke unvested allocations and upgrade the proxy to a malicious implementation.

- **Initializer Protection:**  
  All implementation contract constructors call `_disableInitializers()` to permanently lock implementation initialization, preventing unauthorized front-running takeovers.

- **Reentrancy & Safe Transfers:**  
  All token transfers in `TajirVestingWallet` utilize OpenZeppelin `SafeERC20` routines to defend against non-standard ERC-20 return values and reentrancy vectors.

---

## Project Structure

```
core-contracts/
├── .github/                                 # GitHub community health files
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug_report.md                    # Structured bug report template
│   │   └── feature_request.md              # Feature request template
│   └── PULL_REQUEST_TEMPLATE.md            # PR checklist
├── lib/                                     # Git submodules
│   ├── forge-std/                           # Foundry standard library
│   ├── openzeppelin-contracts/              # OpenZeppelin standard contracts
│   └── openzeppelin-contracts-upgradeable/  # OpenZeppelin upgradeable contracts
├── script/                                  # Deployment & configuration scripts
│   ├── DeployToken.s.sol                    # Genesis deployment: TajirToken + proxy
│   └── DeployVesting.s.sol                  # Tokenomics vesting wallet deployment
├── src/                                     # Core smart contracts
│   ├── interfaces/
│   │   ├── ITajirToken.sol                  # External interface for TajirToken
│   │   └── ITajirVestingWallet.sol          # External interface for TajirVestingWallet
│   ├── token/
│   │   ├── TajirToken.sol                   # L1 gas token ERC-20 (UUPS upgradeable)
│   │   └── TajirTokenProxy.sol              # ERC-1967 proxy for TajirToken
│   └── TajirVestingWallet.sol               # Cliff & tranche-based vesting implementation
├── test/                                    # Test suite
│   ├── fuzz/                                # Property-based & fuzz tests
│   │   └── TajirVestingWallet.t.sol
│   ├── invariant/                           # Invariant tests (4 protocol invariants)
│   │   └── TajirVestingWallet.t.sol
│   └── unit/                                # Unit test suite
│       ├── TajirToken.t.sol
│       └── TajirVestingWallet.t.sol
├── .env.example                             # Environment variable template
├── .gitignore                               # Git ignore rules
├── .gitmodules                              # Submodule configurations
├── .solhint.json                            # Solidity linting rules
├── CHANGELOG.md                             # Release history (Keep a Changelog format)
├── CONTRIBUTING.md                          # Contributor guide
├── deployments.toml.example                 # Deployment config schema template
├── foundry.lock                             # Foundry lockfile
├── foundry.toml                             # Foundry build and network profiles
├── LICENSE                                  # MIT License
├── README.md                                # Project documentation
└── SECURITY.md                              # Vulnerability disclosure policy
```

---

## Contributing

We welcome contributions from the global developer community. Please read [`CONTRIBUTING.md`](./CONTRIBUTING.md) for the full guide covering setup, branch policy, commit conventions, code standards, and the PR process.

**Quick checklist before opening a PR:**
- Target the `develop` branch
- Run `forge fmt`, `forge test`, and `solhint "src/**/*.sol"`
- Fill in the PR template completely
- Never commit private keys, seed phrases, or `.env` files

For complex architectural changes, open an [Issue](../../issues) first to align with the core team.


---

## Security

The security of the Tajir Chain core infrastructure is paramount. If you discover a vulnerability, **please do not open a public GitHub Issue.**

| Channel                        | Contact                                                    |
| :----------------------------- | :--------------------------------------------------------- |
| 🛡️ **Smart Contract Bugs**     | [Immunefi Bug Bounty](https://immunefi.com/bounty/polygon) |
| 🔒 **Direct Security Contact** | `security@tajirchain.io`                                   |

Please review our full [Security Policy](./SECURITY.md) before submitting a report.

---

## License

```
MIT License

Copyright (c) 2024–2026 Tajir Chain

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

<div align="center">

**Built with ❤️ by the Tajir Chain Engineering Team**

[Website](https://tajirchain.com) &nbsp;·&nbsp; [Documentation](https://docs.tajirchain.com) &nbsp;·&nbsp; [Twitter / X](https://x.com/tajirchain)

<sub>© 2026 Tajir Holdings. All rights reserved.</sub>

</div>
