# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)  
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Added
- Invariant test suite for `TajirVestingWallet` (`test/invariant/`)
- `src/interfaces/ITajirToken.sol` — full external interface for integrators
- `src/interfaces/ITajirVestingWallet.sol` — full external interface for integrators
- `script/DeployToken.s.sol` — genesis deployment script for `TajirToken` + proxy
- `deployments.toml.example` — documented config schema for deployment scripts
- `SECURITY.md` — vulnerability disclosure policy and bug bounty information
- `CONTRIBUTING.md` — contributor guide with setup, standards, and PR process
- `LICENSE` — MIT license file
- `.github/workflows/ci.yml` — automated CI: build, test, lint, coverage
- `.github/ISSUE_TEMPLATE/bug_report.md` — structured bug report template
- `.github/ISSUE_TEMPLATE/feature_request.md` — structured feature request template
- `.github/PULL_REQUEST_TEMPLATE.md` — PR checklist template
- `.env.example` — environment variable template
- `deployments.toml.example` — deployment config schema template

### Changed
- Updated tokenomics in `README.md` and `script/DeployVesting.s.sol` to the official 9-category 650M TJR schedule
- Updated OpenZeppelin version references from `v5.0` to `v5.5.0` throughout
- Fixed `pragma solidity ^0.8.20` → `^0.8.27` in `src/token/TajirToken.sol` for consistency
- Expanded `.gitignore` with comprehensive security rules for public repos
- Updated `README.md` to match `bridge-ui` documentation style and structure

---

## [1.0.0] — 2026-08

### Added
- `src/token/TajirToken.sol` — fixed-supply (650M TJR) ERC-20 token with ERC-2612 Permit and UUPS upgradeability
- `src/token/TajirTokenProxy.sol` — ERC-1967 proxy for `TajirToken`
- `src/TajirVestingWallet.sol` — cliff-and-tranche vesting contract with ERC-7201 namespaced storage and separated `admin`/`upgrader` roles
- `script/DeployVesting.s.sol` — deployment script for all vesting wallet instances
- `test/unit/TajirToken.t.sol` — unit tests for the ERC-20 token
- `test/unit/TajirVestingWallet.t.sol` — comprehensive unit tests for the vesting wallet
- `test/fuzz/TajirVestingWallet.t.sol` — property-based fuzz tests
- `foundry.toml` — Foundry build config with optimizer, EVM target, and network profiles
- `.solhint.json` — Solidity linting rules based on `solhint:recommended`

---

[Unreleased]: https://github.com/Tajir-Chain/core-contracts/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/Tajir-Chain/core-contracts/releases/tag/v1.0.0
