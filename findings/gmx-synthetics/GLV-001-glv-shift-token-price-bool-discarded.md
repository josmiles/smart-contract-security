# GLV-001: GlvShiftUtils Discards glvTokenPriceUsed Boolean

**Auditor:** Joseph Kamanja  
**Date:** May 2026  
**Target:** gmx-synthetics (GMX V2)  
**Repo:** github.com/gmx-io/gmx-synthetics  
**Commit:** 708171048fd22114112969f307e78f15389819a8 (GLV oracle fix)  
**Severity:** Informational  
**Status:** Not submitted — no financial impact confirmed  

---

## Summary

After the GLV oracle price count fix (commit `70817104`), the `getGlvValue` 
function was updated to return a tuple `(uint256 glvValue, bool glvTokenPriceUsed)`.
The boolean indicates whether the GLV token price shortcut was used versus 
the full market-by-market calculation. This boolean is used by deposit and 
withdrawal handlers to pass the correct oracle price count to `GasUtils.payExecutionFee`.

`GlvShiftUtils.sol` discards this boolean at line 240:

```solidity
(cache.glvValue, ) = GlvUtils.getGlvValue(
    params.dataStore,
    params.oracle,
    glvShift.glv(),
    true // maximize
);
```

---

## Investigation

We checked whether this discarded boolean causes an execution fee miscalculation.

`GasUtils.estimateGlvDepositOraclePriceCount` and 
`GasUtils.estimateGlvWithdrawalOraclePriceCount` both take `glvTokenPriceUsed`
as a parameter:

```solidity
// glvTokenPriceUsed = true  → returns 4 + swapsCount
// glvTokenPriceUsed = false → returns 2 + marketCount + swapsCount
```

For a GLV with 10 markets, this is a difference of up to 8 oracle prices.

However, after full investigation:

1. `GlvShiftUtils` has **zero references** to `estimateGlvShiftOraclePriceCount`
2. Confirmed via grep: no such function exists anywhere in the codebase
3. The `GlvShiftHandler` confirms: `executionFee is not used for GlvShift's`
4. GLV shifts have **no execution fee** — keepers are not paid per shift

Therefore the discarded boolean has no impact on any fee calculation.
The bool is only used for event emission (`emitGlvValueUpdated`) where
the exact price count is irrelevant.

---

## Impact

**None.** GLV shifts do not charge execution fees. The discarded boolean 
cannot cause overpayment, underpayment, or any financial loss.

---

## Severity

**Informational** — code quality observation only. The fix applied to 
deposit and withdrawal handlers was not needed for the shift handler 
because shifts have no fee mechanism.

---

## Lessons Learned

- Bugs cluster around recent fixes — the right instinct, wrong file
- Always confirm whether execution fees exist before pursuing fee miscalculation angles
- `grep -n "payExecutionFee\|oraclePriceCount"` on the target file immediately 
  answers whether fee manipulation is possible

---

## References

- Commit: `708171048fd22114112969f307e78f15389819a8` — GLV fix oracle price count estimation
- `contracts/glv/glvShift/GlvShiftUtils.sol` line 240
- `contracts/gas/GasUtils.sol` lines 357-380
- `contracts/exchange/GlvShiftHandler.sol` line 162
