---
name: Bug Report
about: Report a bug or unexpected behaviour in the smart contracts
title: "[BUG] "
labels: bug
assignees: ''
---

## Bug Description

<!-- A clear and concise description of what the bug is. -->

## Contract(s) Affected

- [ ] `TajirToken`
- [ ] `TajirTokenProxy`
- [ ] `TajirVestingWallet`
- [ ] Deployment script (`DeployVesting.s.sol`)
- [ ] Other: 

## Steps to Reproduce

1. 
2. 
3. 

## Expected Behaviour

<!-- What did you expect to happen? -->

## Actual Behaviour

<!-- What actually happened? Include any error messages. -->

## Reproduction Test Case

<!-- If possible, provide a Foundry test demonstrating the bug -->

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";

contract BugReproductionTest is Test {
    function test_reproduce_bug() public {
        // ...
    }
}
```

## Environment

- Foundry version (`forge --version`): 
- Solidity version: 
- Network: `[ ] local (Anvil)  [ ] Sepolia  [ ] Mainnet`

## Additional Context

<!-- Any other context, screenshots, or links that might help. -->

---

> ⚠️ **If this is a security vulnerability**, please **do not** open a public Issue.  
> Follow our [Security Policy](../../SECURITY.md) to report it privately.
