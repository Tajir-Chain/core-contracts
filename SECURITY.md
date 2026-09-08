# Security Policy

<div align="center">

**We take the security of Tajir Chain Core Contracts extremely seriously.**  
Please read this policy carefully before submitting any vulnerability report.

</div>

---

## Supported Versions

Only the latest deployed version of each contract is eligible for bug bounty rewards:

| Contract                                | Version                        | Status           |
| :-------------------------------------- | :----------------------------- | :--------------- |
| `TajirToken`                            | `v1.x` (current mainnet proxy) | ✅ Supported     |
| `TajirVestingWallet`                    | `v1.x` (current mainnet proxy) | ✅ Supported     |
| Historical / deprecated implementations | `< v1.0`                       | ❌ Not supported |

---

## Reporting a Vulnerability

> ⚠️ **Do NOT open a public GitHub Issue for security vulnerabilities.**  
> Public disclosure before a fix is deployed puts user funds at risk.

### Channels

| Severity                                    | Channel                                                    | Response SLA |
| :------------------------------------------ | :--------------------------------------------------------- | :----------- |
| 🔴 **Critical / High** (fund loss risk)     | `devs@tajirchain.com`                                      | 24 hours     |
| 🟠 **Medium** (logic / access control flaw) | `devs@tajirchain.com`                                      | 48 hours     |
| 🟡 **Low / Informational**                  | `devs@tajirchain.com`                                      | 7 days       |

### Email Template

When contacting `devs@tajirchain.com`, please include:

```
Subject: [SECURITY] <brief description>

Severity: Critical / High / Medium / Low
Affected Contract(s): TajirToken / TajirVestingWallet / Both
Network: Mainnet / Sepolia / Testnet

Description:
<A clear description of the vulnerability>

Steps to Reproduce:
1. ...
2. ...

Impact:
<What an attacker could achieve>

Suggested Fix (optional):
<If you have a suggested mitigation>

PoC / Test Case (optional):
<Paste or attach a Foundry test demonstrating the issue>
```

---

## Scope

### In Scope ✅

- [`src/token/TajirToken.sol`](./src/token/TajirToken.sol) — ERC-20 logic, mint, burn, permit
- [`src/token/TajirTokenProxy.sol`](./src/token/TajirTokenProxy.sol) — ERC-1967 proxy
- [`src/TajirVestingWallet.sol`](./src/TajirVestingWallet.sol) — Cliff, tranche, revocation
- Upgrade authorization (UUPS `_authorizeUpgrade`)
- Role management (`UPGRADER_ROLE`, `admin`, `upgrader`)
- ERC-7201 storage collision vulnerabilities
- Initialization front-running attacks
- Reentrancy vulnerabilities

### Out of Scope ❌

- Third-party dependencies (`lib/openzeppelin-contracts`, `lib/forge-std`)
- Deployment scripts — these are informational only
- Off-chain infrastructure (bridge APIs, indexers, UI)
- Theoretical attacks requiring attacker to control governance multisig
- Denial-of-service attacks that do not result in direct fund loss
- Best practices / style suggestions — please open a regular Issue instead

---

## Disclosure Policy

1. **Acknowledgement** — We acknowledge receipt of your report within the SLA above.
2. **Investigation** — Our security team assesses severity and reachability.
3. **Fix & Deployment** — We develop, audit, and deploy a patch. For UUPS contracts this may involve an upgrade transaction.
4. **Coordinated Disclosure** — We coordinate a public disclosure date with the reporter (typically 7–30 days after fix deployment).
5. **Credit** — Reporters are credited in the public disclosure unless they prefer anonymity.

---

## Bug Bounty

Critical and High severity confirmed vulnerabilities are eligible for rewards via the **Immunefi** program. Reward amounts are determined by:

- Severity and exploitability
- Quality and completeness of the report
- Whether a working PoC is provided

See the [Immunefi bounty page](https://immunefi.com/bounty/polygon) for current reward tiers.

---

## Contact

| Channel           | Address                                         |
| :---------------- | :---------------------------------------------- |
| 📧 Security Email | `devs@tajirchain.com`                           |
| 🛡️ Bug Bounty     | [Immunefi](https://immunefi.com/bounty/polygon) |
| 🌐 Website        | [tajirchain.com](https://tajirchain.com)        |

---

<div align="center">

<sub>© 2026 Tajir Holdings. All rights reserved.</sub>

</div>
