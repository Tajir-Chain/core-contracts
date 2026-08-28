# Contributing to Tajir Chain Core Contracts

Thank you for your interest in contributing to the Tajir Chain smart contract infrastructure. This guide covers everything you need to get started.

---

## Code of Conduct

All contributors are expected to act professionally and respectfully. Harassment, discrimination, or hostile behaviour of any kind will not be tolerated.

---

## Getting Started

### Prerequisites

| Tool | Version | Installation |
| :--- | :--- | :--- |
| [Git](https://git-scm.com/) | Latest | OS package manager |
| [Foundry](https://book.getfoundry.sh/) | Latest | `curl -L https://foundry.paradigm.xyz \| bash && foundryup` |

### Local Setup

```bash
# 1. Fork the repository on GitHub, then clone your fork
git clone --recurse-submodules https://github.com/<your-username>/core-contracts.git
cd core-contracts

# 2. Add the upstream remote
git remote add upstream https://github.com/Tajir-Chain/core-contracts.git

# 3. Set up environment
cp .env.example .env
cp deployments.toml.example deployments.toml
# Edit .env and deployments.toml with your local values

# 4. Build and verify
forge build
forge test
```

---

## Branch Policy

| Branch | Purpose |
| :--- | :--- |
| `main` | Production-grade code — protected, only merged via release PRs |
| `develop` | Integration branch — **all PRs must target this branch** |
| `feat/<name>` | Feature development |
| `fix/<name>` | Bug fixes |
| `chore/<name>` | Maintenance tasks |

> ⚠️ **Never open a PR directly to `main`.**

---

## Commit Conventions

We follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <short description>

[optional body]

[optional footer]
```

| Type | When to use |
| :--- | :--- |
| `feat` | New feature or contract behaviour |
| `fix` | Bug fix |
| `refactor` | Code restructuring without behaviour change |
| `test` | Adding or updating tests |
| `docs` | Documentation only |
| `chore` | Build scripts, CI, config changes |
| `security` | Security-related fixes |

**Examples:**

```
feat(vesting): add emergency pause for admin
fix(token): correct permit nonce validation
test(vesting): add fuzz test for cliff boundary
docs(readme): update tokenomics table
```

---

## Pull Request Process

1. **Open an Issue first** for non-trivial changes to align with the core team.
2. **Branch from `develop`**: `git checkout -b feat/my-feature develop`
3. Write or update **unit + fuzz tests** for all changed logic.
4. Run the full quality checklist locally:
   ```bash
   forge build
   forge test -vvv
   forge fmt --check
   ```
5. Open a PR against `develop`, filling in the **PR template** completely.
6. All CI checks must pass before review.
7. At least **1 core team review** is required before merge.

---

## Code Standards

### Solidity Style

- **Pragma**: `pragma solidity ^0.8.27;` — do not use older versions
- **SPDX**: `// SPDX-License-Identifier: MIT` on every file
- **NatSpec**: All `external` and `public` functions must have `@notice` and `@param`
- **Custom errors**: Use `error Name()` — no `require("string")` messages
- **SafeERC20**: Use `SafeERC20` for all ERC-20 token transfers
- **Storage**: New upgradeable state must use ERC-7201 namespaced storage slots

### Formatting

All code must pass:

```bash
forge fmt --check   # check
forge fmt           # auto-format
```

### Linting

```bash
npx solhint "src/**/*.sol" --config .solhint.json
```

---

## Testing Requirements

| Test Type | Minimum Coverage |
| :--- | :--- |
| Unit tests | Every public/external function |
| Fuzz tests | All numeric/address parameters |
| Invariant tests | Core protocol properties |

Run all test suites:

```bash
forge test                               # All tests
forge test --match-path test/unit/**     # Unit only
forge test --match-path test/fuzz/**     # Fuzz only
forge test --match-path test/invariant/**# Invariant only
forge snapshot                           # Gas benchmarks
```

---

## Security

- **Never commit private keys, seeds, or `.env` files.**
- If you discover a security vulnerability, please follow our [Security Policy](./SECURITY.md).
- **Do not open a public GitHub Issue for security vulnerabilities.**

---

## Getting Help

- Open a [GitHub Discussion](../../discussions) for questions
- Open a [GitHub Issue](../../issues) for bugs or feature requests
- Reach the core team at `dev@tajirchain.io`
