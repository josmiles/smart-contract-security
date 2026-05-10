# Audit Report - OpenZeppelin Uniswap Hooks v1.2.1

| Field | Details |
|-------|---------|
| Auditor | Joseph Kamanja |
| Target | OpenZeppelin Uniswap Hooks |
| Repo | github.com/OpenZeppelin/uniswap-hooks |
| Commit | 2c39623 |
| Date | 2026-05-10 |
| Scope | src/general/ReHypothecationHook.sol |

---

## [F-01] _resolveHookDelta withdraws swap fees from vault causing permanent DoS on first swap

| Property | Value |
|----------|-------|
| Severity | High |
| Category | Logic Error - Fee Accounting |
| Location | src/general/ReHypothecationHook.sol Lines 265-275 |
| Status | Submitted to Immunefi |

### Description

ReHypothecationHook deposits LP assets into ERC-4626 vaults while
providing JIT liquidity for swaps. After each swap, _afterSwap removes
the JIT position and calls _resolveHookDelta to settle currency deltas.

When a swap executes, fees accrue inside the Uniswap V4 pool. When the
hook removes its JIT liquidity in _afterSwap, the returned currencyDelta
includes the original deposited amount PLUS swap fees. _resolveHookDelta
then calls _withdrawFromYieldSource(deposit + fees). The ERC-4626 vault
only holds the originally deposited assets. Fees accrued inside the pool
are not held in the vault. The withdrawal reverts with arithmetic underflow.

This revert propagates through _afterSwap, causing every swap to revert
permanently from the very first swap. No attacker required.

### Vulnerable Code

```solidity
// src/general/ReHypothecationHook.sol Lines 265-275
function _resolveHookDelta(Currency currency) internal virtual {
    int256 currencyDelta = poolManager.currencyDelta(address(this), currency);
    if (currencyDelta < 0) {
        _withdrawFromYieldSource(currency, (-currencyDelta).toUint256());
        // currencyDelta includes fees not held in vault - REVERTS
        currency.settle(poolManager, address(this), (-currencyDelta).toUint256(), false);
    }
}

// src/mocks/general/ReHypothecationERC4626Mock.sol Lines 77-80
function _withdrawFromYieldSource(Currency currency, uint256 amount) internal virtual override {
    IERC4626 yieldSource = IERC4626(getCurrencyYieldSource(currency));
    yieldSource.withdraw(amount, address(this), address(this)); // reverts
}
```

### Attack Scenario

1. LP deposits via addReHypothecatedLiquidity(shares)
   Assets flow into ERC-4626 vault - vault holds exactly deposited amount
2. Swap executes - _beforeSwap adds JIT liquidity from vault into pool
3. Swap collects fees - fees accrue INSIDE the pool, not in the vault
4. _afterSwap removes liquidity - currencyDelta = deposit + fees
5. _resolveHookDelta calls _withdrawFromYieldSource(deposit + fees)
6. Vault only holds deposit - revert arithmetic underflow
7. afterSwap reverts - ALL swaps revert permanently
8. Pool is permanently bricked from the very first swap

### Impact

- Pool completely unusable from the first swap
- No attacker required - triggered by normal swap activity
- No recovery path in the base contract
- ReHypothecationHook not covered by any of the three audit reports
- LPs can still exit via removeReHypothecatedLiquidity

### Verification

```bash
# Confirm withdrawal in mock
grep -n "withdraw" src/mocks/general/ReHypothecationERC4626Mock.sol

# Confirm _resolveHookDelta called in _afterSwap
grep -n "_resolveHookDelta" src/general/ReHypothecationHook.sol

# Confirm not in any audit
grep -r "ReHypothecation" audits/ 2>/dev/null || echo "Not in audit scope"
```

### Recommended Fix

Only withdraw from vault what was deposited.
Handle fee delta separately without going through the vault.

```solidity
function _resolveHookDelta(Currency currency) internal virtual {
    int256 currencyDelta = poolManager.currencyDelta(address(this), currency);
    if (currencyDelta < 0) {
        uint256 amount = (-currencyDelta).toUint256();
        uint256 vaultBalance = _getAmountInYieldSource(currency);
        uint256 fromVault = amount > vaultBalance ? vaultBalance : amount;
        if (fromVault > 0) _withdrawFromYieldSource(currency, fromVault);
        currency.settle(poolManager, address(this), amount, false);
    }
}
```

### References
- src/general/ReHypothecationHook.sol Lines 265-275
- src/mocks/general/ReHypothecationERC4626Mock.sol Lines 77-80
- Immunefi submission: Report pending
- PoC Gist: gist.github.com/josmiles/c7b2930b0dcb5e1e98c3d5fda09778f0

### Status
- [x] Finding identified
- [x] Verified not in any audit report
- [x] Verified no existing GitHub issue
- [x] Foundry PoC written and passing
- [x] Submitted to Immunefi
