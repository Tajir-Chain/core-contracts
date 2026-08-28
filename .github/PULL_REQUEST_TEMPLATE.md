## Description

<!-- A clear and concise description of what this PR does and why. -->

## Related Issue(s)

Closes # <!-- Link the issue this PR resolves, e.g. Closes #42 -->

## Type of Change

- [ ] 🐛 Bug fix (non-breaking change that fixes an issue)
- [ ] ✨ New feature (non-breaking change that adds functionality)
- [ ] 💥 Breaking change (fix or feature that would cause existing functionality to change)
- [ ] 🔒 Security fix
- [ ] 📄 Documentation update
- [ ] 🔧 Chore / refactor (no functional changes)

## Changes Made

<!-- List all files and contracts modified, added, or removed. -->

- `src/...` — 
- `test/...` — 
- `script/...` — 

## Storage Layout Impact

- [ ] No changes to storage layout
- [ ] Storage layout changed — migration path described below:

<!-- If storage layout changed, describe the migration path for existing proxies. -->

## Testing

- [ ] All existing tests pass (`forge test`)
- [ ] New unit tests added for all changed logic
- [ ] Fuzz tests added / updated
- [ ] Invariant tests checked
- [ ] Gas snapshot updated (`forge snapshot`)

## Security Checklist

- [ ] No private keys, secrets, or RPC credentials in this PR
- [ ] No `require(string)` — custom errors used throughout
- [ ] All public/external functions have NatSpec
- [ ] Re-entrancy risks evaluated
- [ ] `SafeERC20` used for all token transfers
- [ ] Access control checked on all state-changing functions

## Pre-Merge Checklist

- [ ] `forge fmt` run and all files formatted
- [ ] `forge build --sizes` passes with no size warnings
- [ ] Targeting `develop` branch (not `main`)
- [ ] Conventional Commits format used (`feat:`, `fix:`, etc.)
