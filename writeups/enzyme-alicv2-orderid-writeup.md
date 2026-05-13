# Writeup — Enzyme Blue AliceV2PositionLib OrderId Collision

| Field | Details |
|-------|---------|
| Auditor | Joseph Kamanja |
| Protocol | Enzyme Blue |
| Contract | contracts/release/extensions/external-position-manager/external-positions/alice-v2/AliceV2PositionLib.sol |
| Functions | `__addOrder()`, `__placeOrderWithRefId()` |
| Commit | dev branch HEAD |
| Date | May 13, 2026 |
| Report ID | 77814 |
| Status | Escalated — awaiting Enzyme Blue response |
| Severity Submitted | High |
| Target Asset | 0xa2868b1b0fc224b105c7be46d31aeec0c843d74d (Ethereum mainnet) |

---

## What We Found

`AliceV2PositionLib.__addOrder()` predicts the orderId using
`getMostRecentOrderId() + 1` BEFORE `placeOrder()` executes and stores
it in the EP's mapping:

```solidity
// VULNERABLE — current dev branch
uint256 orderId = ALICE_INSTANT_ORDER_V2.getMostRecentOrderId() + 1;
orderIds.push(orderId);
orderIdToOrderDetails[orderId] = _orderDetails;  // stored BEFORE placeOrder
// placeOrder called after — actual id may differ
```

Alice's `getMostRecentOrderId()` returns a **global sequential counter
shared across all callers**. Alice's `placeOrder()` returns void — there
is no way to read back the actual assigned orderId after the call.

When two Enzyme vaults place Alice V2 orders in the same Ethereum block,
both read the same counter value before either `placeOrder` executes.
Both predict `N+1`. Vault A gets `N+1` (correct). Vault B gets `N+2`
(actual) but stored `N+1` (wrong).

---

## The Downstream Failure Chain

```
Vault B stores referenceId = bytes32(N+1)    ← wrong
Alice assigns actual orderId = N+2
Alice settles order N+2:
  → calls EP_B.notifySettle(WETH, amount, bytes32(N+2))
  → isPendingReferenceId(bytes32(N+2)) = FALSE
  → revert InvalidReferenceId()
  → Alice's settlement transaction reverts
  → Vault B never receives incoming WETH
  → No recovery path via normal protocol flows
```

Confirmed from `notifySettle` source (line 82):

```solidity
if (!isPendingReferenceId(_referenceId)) {
    revert InvalidReferenceId();   // fires for Vault B
}
```

---

## Why This Is a Real Finding

**Zero privileges required.** Two innocent vault managers both using
Alice V2 in the same block trigger this deterministically. No attacker,
no coordination, no special state required.

**No recovery path.** `notifySettle` is the only way Alice communicates
settlement back to the EP. Once it reverts, Alice has no retry mechanism.
The vault permanently loses its incoming trade proceeds.

**Alice's placeOrder is void.** The prediction is the only available
mechanism — and it is racy on a shared global counter.

```solidity
// IAliceInstantOrderV2.sol
function placeOrder(...) external payable;  // void — no orderId returned
```

---

## Proof of Concept

**Gist:** https://gist.github.com/josmiles/c5d71d7d323eea2f88924e2fb34083ae

**Test output (1/1 passing against real Alice V2 on mainnet):**

```
[PASS] testAliceV2OrderIdCollision() (gas: 4319077)
[*] Counter before orders : 69
[*] Both vaults predict   : 70
[VaultA] stored orderId   : 70  actual: 70  match: true
[VaultB] stored (WRONG)   : 70  actual: 71  MISMATCH: true
[*] notifySettle REVERTED - InvalidReferenceId
[VaultB] notifySettle reverted: true
Impact: Alice settlement TX reverts, VaultB never receives incoming WETH
Suite result: ok. 1 passed; 0 failed; 0 skipped
```

**Three assertions passing:**
1. `epB_stored != epB_actual` — orderId collision confirmed
2. `epB_notifyReverted == true` — settlement reverts confirmed
3. `epA_stored == epA_actual` — Vault A unaffected

---

## Why the Previous Audit Did Not Catch This

The 2024-05 Chainsecurity audit covered Alice V1. Alice V2 was added in
October 2025 (commits `02c4d2133`, `e28dd43e5`, `6fd7656b0`, `58163e39f`)
after that audit. Alice V2 received only an internal audit. The internal
audit (commit `e28dd43e5`) fixed a distinct issue — wrong referenceId
calculation for `PlaceOrderWithRefId`. The `__addOrder` prediction
vulnerability was not addressed.

---

## Recommended Fix

Call `placeOrder` first, then read the actual assigned orderId:

```solidity
// FIXED — read AFTER placeOrder executes
function __addOrder(OrderDetails memory _orderDetails) private {
    uint256 orderId = ALICE_INSTANT_ORDER_V2.getMostRecentOrderId(); // no +1
    orderIds.push(orderId);
    orderIdToOrderDetails[orderId] = _orderDetails;
}
```

The caller restructures to call Alice first, then `__addOrder`. The
referenceId for `PlaceOrderWithRefId` also needs the same post-call
pattern.

---

## What Enzyme Will Likely Argue

**Probability argument:** Alice V2 had 69 total orders at time of
testing — very low usage. Two vaults in the same block is currently
unlikely.

**Counter-argument:** The bug is architectural, not probabilistic.
Any increase in Alice V2 adoption increases the collision probability.
The fix is trivial. The risk scales with adoption.

---

## Key Lessons Learned

### 1. Global shared counters are always racy in multi-caller systems

Any external protocol that uses a global sequential counter and returns
void from its placement function creates this exact vulnerability pattern.
Always check:

```
Does the external call return the assigned ID?
If NO → is the counter global and shared?
If YES → race condition exists for same-block callers
```

### 2. The fix pattern for void-return external IDs

```
WRONG: predict → store → call
RIGHT: call → read actual → store
```

### 3. Internal audits miss cross-contract race conditions

The internal audit fixed a calculation bug but missed the timing bug.
Race conditions between separate callers require explicit multi-tx
thinking, not just single-tx code review.

### 4. Check what previous audits actually covered

The 2024-05 audit covered Alice V1. Alice V2 added in Oct 2025 was
out of scope. Always grep audit reports for the specific contract name
before claiming "not in any audit."

---

## Current Status

Escalated to Enzyme Blue on May 13, 2026 at 12:20am.
Immunefi SLA: 14 days (resolution by May 27, 2026).
Payout range if confirmed: $5,000 — $20,000 USDC.

---

## References

- Enzyme Blue Immunefi programme: immunefi.com/bug-bounty/enzymefinance/
- Report ID: 77814
- PoC Gist: gist.github.com/josmiles/c5d71d7d323eea2f88924e2fb34083ae
- AliceV2PositionLib: etherscan.io/address/0xa2868b1b0fc224b105c7be46d31aeec0c843d74d
- Alice V2 contract: 0x6F13230851B7e00e3e79277DccE6953140D8302D
- Chainsecurity 2024-05 audit: covers Alice V1 only
