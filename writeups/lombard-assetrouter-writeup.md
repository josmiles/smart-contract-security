# Writeup — Lombard Finance AssetRouter._redeem() Mint/Burn Ordering

| Field | Details |
|-------|---------|
| Auditor | Joseph Kamanja |
| Protocol | Lombard Finance |
| Contract | contracts/LBTC/AssetRouter.sol |
| Commit | cc2cfd78371fbea7a38bd4aea81340be17dbd6a0 |
| Date | May 11, 2026 |
| Report ID | 77600 |
| Status | Closed — Invalid |
| Severity Submitted | Medium |

---

## What We Found

`AssetRouter._redeem()` executes fee redistribution in this order:

```solidity
// VULNERABLE ordering
tokenContract.mint(tokenContract.getTreasury(), fee);  // mint first
tokenContract.burn(fromAddress, amount + fee);          // burn second
```

Between these two calls, `totalSupply` is transiently inflated by `fee`.
The invariant `totalSupply(LBTC) == totalBTCLocked` is violated in the
intermediate state.

The correct reference exists three functions away in the same file:

```solidity
// _mintWithFee() -- CORRECT ordering
tokenContract.burn(fromAddress, amount + fee);   // burn first
tokenContract.mint(treasury, fee);               // mint second
```

Same contract, same author, opposite ordering. Clear implementation
inconsistency.

---

## Why We Submitted It

- Fires on every redemption with non-zero fee
- Zero privileges required
- Not in any of 13 audit reports covering the codebase
- Foundry PoC passing with 3/3 tests on mainnet fork
- Clear correct reference in same file

---

## Why Lombard Closed It

> "Reading the intermediate state is not possible from outside the
> transaction -- both operations execute atomically within _redeem,
> and no external code is invoked between them."

**They are correct.**

On the EVM, a transaction executes atomically. No external contract
can observe intermediate state mid-transaction unless:

1. An external call is made between the two operations
2. The external call triggers a callback (reentrancy)
3. The external contract reads state inside that callback

In `_redeem()`:
- `nonReentrant` modifier prevents reentrancy
- No external calls are made between mint and burn
- The Mailbox.send() call happens BEFORE both token operations

Therefore no external contract can ever observe the inflated
`totalSupply` between the mint and the burn. The violation exists
only in the EVM execution trace — not in any observable state.

**The finding is a real code inconsistency but not an exploitable
security vulnerability under the current implementation.**

---

## What We Got Wrong

**The EVM atomicity principle:**

Transactions on Ethereum are atomic. State changes within a single
transaction are not visible to external contracts UNLESS an external
call is made and the called contract reads state.

We argued that "price oracles reading totalSupply() in the same block"
would observe the inflated value. This is incorrect — oracles in
SEPARATE transactions in the same block read the FINAL state after the
transaction completes, not intermediate state mid-transaction.

For the intermediate state to be observable externally, the sequence
would need to be:

```
mint(treasury, fee)           ← totalSupply inflated
external_call()               ← calls external contract
  └─ externalContract reads totalSupply()  ← sees inflated value
burn(fromAddress, amount+fee) ← totalSupply corrected
```

`_redeem()` has no external call between mint and burn. Therefore
the intermediate state is never observable.

---

## The Latent Reentrancy Argument

We argued that if LBTC ever gains ERC-777 `tokensReceived` hooks,
the wrong ordering becomes a reentrancy vector.

Lombard did not address this directly but it is a future-state argument.
Bug bounties pay for current vulnerabilities, not hypothetical ones
based on future token upgrades.

---

## Key Lesson for Future Reports

**EVM atomicity kills most "intermediate state" arguments.**

Before submitting any finding based on intermediate state violations:

Ask: "Is there an external call between the two operations that
creates an observable window?"

If NO external call → intermediate state is not observable → not a
security vulnerability → at most a best practice recommendation.

If YES external call → check if it can be exploited → potential finding.

**Checklist for intermediate state findings:**

```
1. What is the sequence of operations?
2. Is there an external call between operations A and B?
3. If yes — can that external call read the intermediate state?
4. If yes — can the external call be controlled by an attacker?
5. If yes to all four — real finding
6. If no external call — not exploitable — do not submit as security bug
```

---

## What This Was Worth

Even though closed, this exercise was valuable:

- We read a real protocol with real TVL ($40M vault)
- We found a real code inconsistency (mint/burn ordering mismatch)
- We wrote a mainnet fork PoC that runs against live contracts
- We learned the EVM atomicity principle the hard way
- We improved our pre-submission checklist

The finding is worth documenting as a **best practice recommendation**
and submitting as a GitHub issue to the protocol — not as a security
bounty.

---

## The Correct Fix (Still Valid as Best Practice)

Even though not exploitable today, the correct ordering mirrors
`_mintWithFee()` and should be applied for consistency and to prevent
future vulnerability if the token architecture changes:

```solidity
// RECOMMENDED (mirrors _mintWithFee in same contract)
tokenContract.burn(fromAddress, amount + fee);
if (fee > 0) {
    tokenContract.mint(tokenContract.getTreasury(), fee);
}
```

---

## Updated Pre-Submission Checklist Addition

Added to our hunting process:

> Before submitting any intermediate state / invariant violation finding,
> verify there is an EXTERNAL CALL between the two operations that creates
> an observable window. No external call = not observable = best practice
> only, not a security vulnerability.

---

## References

- Lombard Finance evm-smart-contracts: github.com/lombard-finance/evm-smart-contracts
- Report ID: 77600
- PoC Gist: gist.github.com/josmiles/f526259a5c21c8e42edc7a9b7bef2bf3
- Immunefi response: "Both operations execute atomically within _redeem"
