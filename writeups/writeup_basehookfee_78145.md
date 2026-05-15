# Writeup — OpenZeppelin Uniswap Hooks BaseHookFee Fee Direction Review

| Field | Details |
|-------|---------|
| Auditor | josmile |
| Protocol | OpenZeppelin Uniswap Hooks |
| Contract | src/fee/BaseHookFee.sol (v1.2.0) |
| Commit | 2c39623 (master HEAD) |
| Repo | github.com/OpenZeppelin/uniswap-hooks |
| Platform | Immunefi — immunefi.com/bug-bounty/openzeppelin |
| Date | May 14–15, 2026 |
| Report ID | #78145 |
| Status | CLOSED — Informational |
| Severity Assessed | Medium (our claim) → Informational (OZ response) |

---

## Scope of This Engagement

This engagement covered the `src/fee/` directory of the OpenZeppelin
Uniswap Hooks library — specifically contracts never included in any of
the three prior audit reports (RC1, RC2 v1.0.0, RC2 v1.1.0):

```
src/fee/BaseHookFee.sol         ← primary target
src/fee/BaseDynamicFee.sol      ← reviewed, thin logic
src/fee/BaseOverrideFee.sol     ← reviewed, thin logic
```

`BaseDynamicAfterFee.sol` was in the RC2 audit scope and had a known
finding (M-01) fixed in PR #86. `BaseHookFee.sol` was introduced after
all three audits in PR #65 and had no external audit coverage.

---

## The Finding We Submitted

### Root Cause

`BaseHookFee._afterSwap()` selects the fee currency using the condition:

```solidity
(Currency unspecified, int128 unspecifiedAmount) =
    (params.amountSpecified < 0 == params.zeroForOne)
        ? (key.currency1, delta.amount1())
        : (key.currency0, delta.amount0());
```

This selects the **unspecified** currency — the side the swapper did not
name in their parameters. For exact-output swaps (`amountSpecified > 0`),
the unspecified currency is the INPUT, not the output.

The NOTE at line 60 of the contract states:

```
* NOTE: The fee is calculated as a percentage of the output amount and
* taken as ERC-6909 claims.
```

We read this NOTE as the authoritative specification and concluded the
code was wrong — charging input instead of output. The truth table we
constructed:

```
exact-input  + zeroForOne=true   → TRUE  → currency1 = OUTPUT  ✓
exact-input  + zeroForOne=false  → FALSE → currency0 = OUTPUT  ✓
exact-output + zeroForOne=true   → FALSE → currency0 = INPUT   ✗ (we called this a bug)
exact-output + zeroForOne=false  → TRUE  → currency1 = INPUT   ✗ (we called this a bug)
```

### The PoC

We appended a test to `test/fee/BaseHookFee.t.sol` demonstrating that
for a `zeroForOne=true, amountSpecified=1e18` swap, the hook's
`feeAmount0` (currency0 = INPUT) increased by `6,035,841,794,200` while
`feeAmount1` (currency1 = OUTPUT) remained zero. All three assertions
passed. forge test showed `[PASS]`.

### Why We Thought It Was Medium

RC2 audit finding M-01 identified the identical pattern in
`BaseDynamicAfterFee` and was classified Medium. PR #86 fixed
`BaseDynamicAfterFee` only. `BaseHookFee` was introduced afterward.
We argued this was an incomplete fix of an already-classified Medium.

---

## OZ's Response

OZ escalated the report in 17 minutes (10:31 PM → 10:48 PM). 9 OZ team
members subscribed. Their triage response:

> "The team evaluated the issue as an informational one as the natspec
> was really misleading. Note that the correct behavior is in the natspec
> of the `_afterSwap` function:
> [line 58]
>
> However, the note below it misleads the behavior as if the amount is
> calculated based on the output amount:
> [line 60]
>
> Note that the function behaves as the initial docs, as a percentage of
> the **unspecified**, not the output, amount. The team opened PR #130
> changing `output` to `unspecified` where needed."

OZ confirmed PR #130 was opened to fix the documentation.

---

## Why They Were Right

Reading line 58 carefully reveals OZ's intent:

```solidity
/**
 * @dev Hooks into the `afterSwap` hook to apply the hook fee to the
 * UNSPECIFIED currency.               ← line 58: authoritative spec
 *
 * NOTE: The fee is calculated as a percentage of the OUTPUT amount    ← line 60: wrong NOTE
 * and taken as ERC-6909 claims.
 */
```

The function-level docstring at line 58 says **unspecified currency**.
Line 60's NOTE says **output amount**. These two statements contradict
each other for exact-output swaps. OZ's position: line 58 is the
authoritative specification; line 60 is misdocumentation.

The code correctly implements line 58 — it always charges on the
unspecified side. For exact-input swaps the unspecified side is the
output (fee on output). For exact-output swaps the unspecified side is
the input (fee on input). This is intentional and consistent.

**The bug was in line 60 (a NOTE), not in the code.** OZ's fix (PR #130)
replaces "output" with "unspecified" in the documentation. The code
itself is unchanged.

---

## The Critical Distinction We Missed

In Uniswap V4:

```
"Unspecified" = the side the swapper did NOT name in their parameters
"Output"      = the side the swapper receives

exact-input:  amountSpecified < 0 → input is specified → output is unspecified
              unspecified == output  ✓ (these coincide)

exact-output: amountSpecified > 0 → output is specified → INPUT is unspecified
              unspecified != output  ✗ (these diverge)
```

We conflated "unspecified" with "output" and built our entire finding on
that conflation. The code is internally consistent — it always charges
on the unspecified side. We misread line 60's NOTE as the specification
and treated the consistent unspecified-side charging as a bug.

The distinction matters for any V4 hook that claims to charge fees on
"output." If the NatSpec says "output" but the code charges "unspecified,"
that is only a bug if the NatSpec is authoritative. In this case, the
function-level docstring (line 58, "unspecified currency") overrides the
NOTE (line 60, "output amount"), and line 58 is what OZ intended.

---

## What Made This Hard to Catch Before Submitting

### OZ's own test suite asserted the behavior

`test_swap_zeroForOne_exactOutput` in `test/fee/BaseHookFee.t.sol`
asserts `hookCurrency0Claims == expectedFee` for a zeroForOne
exact-output swap where `currency0` is the INPUT. The comment in that
test is wrong ("exactInput && zeroForOne == false") — it was copy-pasted
from an exact-input test. This made the behavior look like a confirmed
bug because the test was asserting "fee on INPUT" as the expected result,
with a wrong comment suggesting it was asserting "fee on OUTPUT."

What this actually proved: OZ's tests consistently and correctly verify
fee-on-unspecified behavior. The wrong comment was the documentation bug,
not the assertion.

### The M-01 analogy was imprecise

M-01 in `BaseDynamicAfterFee` was a genuine logic error — the contract
tried to charge fee on output but charged on input instead because of a
wrong condition. The fix in PR #86 added explicit `exactInput` branch
logic to correctly separate exact-input vs exact-output handling.

`BaseHookFee` was not trying to charge on output. It was designed to
charge on the unspecified side — which is a different (and valid)
design choice. The analogy held in code structure but not in design
intent, and design intent is what matters for OZ's classification.

---

## What We Did Right

- Read the contract line by line and built a complete truth table
- Checked all three audit PDFs before submitting
- Verified PR #86 file list via GitHub API to confirm it only touched
  `BaseDynamicAfterFee.sol`
- Checked all open issues and PRs for duplicates — none existed
- Built a working PoC that passed `forge test [PASS]`
- Answered all 8 gates before submitting
- The submission was detailed, structured, and professional

The process was correct. The finding classification was wrong.

---

## What We Did Wrong

**We treated line 60 as authoritative over line 58.**

When two NatSpec statements contradict each other, the function-level
docstring (the `@dev` block describing the function's purpose) is more
authoritative than a subordinate NOTE. We should have read line 58 first
and asked: "Does the code correctly implement fee-on-unspecified?" The
answer is yes.

Instead, we read line 60 first and asked: "Does the code correctly
implement fee-on-output?" The answer is no — but that was never the
stated intent.

**We did not ask the right question:** Is "unspecified" the correct
design for a hook fee, or should it be "output"? If we had asked that
question, we would have found the contradiction between line 58 and
line 60 without committing to either one as the bug.

---

## Updated Rules for Fee Direction Bugs in V4 Hooks

```
Before claiming "fee charged on wrong currency":

1. Find the authoritative specification — the @dev function docstring,
   NOT a subordinate NOTE. Read the function-level description first.

2. Distinguish "unspecified" from "output":
   - "unspecified" = design choice, valid for hooks that want symmetric
     fee behavior regardless of swap direction
   - "output" = explicit design choice, requires direction-aware logic

3. If the contract says "unspecified" in the @dev and charges on unspecified
   → NOT A BUG. The code is correct. Any NOTE saying "output" is the
   documentation bug.

4. If the contract says "output" in the @dev and charges on unspecified
   → POTENTIAL BUG. Unspecified = input for exact-output swaps.
   Now apply the truth table and verify M-01 pattern applies.

5. Check whether the test suite asserts the behavior on exact-output swaps.
   If it asserts fee-on-input, ask: is the test wrong or is the code wrong?
   Read the @dev docstring to decide which.
```

---

## The Real Finding in This Contract

There is a genuine documentation inconsistency in `BaseHookFee.sol`:

- **Line 58** (`@dev`): "apply the hook fee to the **unspecified** currency"
- **Line 60** (`NOTE`): "fee is calculated as a percentage of the **output** amount"

These contradict each other for exact-output swaps. OZ agrees — PR #130
fixes the NOTE. This is Informational at best and was correctly
classified as such. It did not warrant a Medium severity claim.

The correct finding to have submitted, had we caught the distinction:

> *Informational: NOTE at line 60 of BaseHookFee.sol incorrectly states
> the fee is calculated as a percentage of the output amount. The @dev
> docstring at line 58 correctly states the fee is on the unspecified
> currency. For exact-output swaps, the unspecified currency is the input,
> not the output. The NOTE should read "unspecified" not "output."*

This would have been acknowledged, credited, and fixed — but paid as
Informational ($0 on OZ's program) or not paid at all.

---

## The Lesson for Future Hunts

**Documentation mismatch = Informational. Wrong math = Medium+.**

The distinction is:
- Does the code implement what the authoritative spec says? If yes → docs bug.
- Does the code implement something different from the authoritative spec? If yes → code bug.

Finding M-01 in `BaseDynamicAfterFee` was a code bug: the code intended
to charge on output but charged on input due to wrong condition logic.
PR #86 fixed the *code*, not the docs.

Finding #78145 in `BaseHookFee` was a docs bug: the code correctly
charged on unspecified as the @dev said. PR #130 fixed the *docs*, not
the code.

Same surface. Different root cause. Different outcome.

---

## Audit Coverage Confirmation

| Audit | Report | Covers BaseHookFee? |
|---|---|---|
| RC1 | OpenZeppelin Uniswap Hooks v1.0.0 RC1 | No |
| RC2 v1.0.0 | OpenZeppelin Uniswap Hooks v1.1.0 RC1 | No |
| RC2 v1.1.0 | OpenZeppelin Uniswap Hooks v1.1.0 RC2 | No |
| PR #86 | Fixed M-01 in BaseDynamicAfterFee only | No |

`BaseHookFee.sol` has never been in any external audit scope. It
remains unaudited for code-level bugs. The documentation fix in PR #130
does not constitute an audit.

---

## References

- Report #78145: immunefi.com (closed, informational)
- BaseHookFee source: github.com/OpenZeppelin/uniswap-hooks/blob/master/src/fee/BaseHookFee.sol
- RC2 audit M-01: OpenZeppelin Uniswap Hooks v1.1.0 RC2 Audit.pdf
- PR #86 (M-01 fix): github.com/OpenZeppelin/uniswap-hooks/pull/86
- PR #130 (docs fix): github.com/OpenZeppelin/uniswap-hooks/pull/130
- PoC Gist: gist.github.com/josmiles/2fdd43e6298c4eff42654bd97ad31c2b
