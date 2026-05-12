# Writeup — Lombard Finance AssetRouter.handlePayload() Mint Pause Permanent Lock

| Field | Details |
|-------|---------|
| Auditor | Joseph Kamanja |
| Protocol | Lombard Finance |
| Contract | contracts/LBTC/AssetRouter.sol |
| Commit | cc2cfd78371fbea7a38bd4aea81340be17dbd6a0 |
| Date | May 12, 2026 |
| Report ID | Not submitted — abandoned at PoC stage |
| Status | Not submitted |
| Severity Assessed | High |

---

## What We Found

`AssetRouter.handlePayload()` marks `$.usedPayloads[payload.id] = true`
BEFORE calling `NativeLBTC.mint()`. `NativeLBTC.mint()` carries the
`whenMintBurnAllowed` modifier and reverts when mint is paused.

`Mailbox._handle()` wraps `handlePayload` in a try/catch and swallows
the revert silently.

The result: if mint is paused when a GMP message is delivered, the
payload is permanently consumed with no recovery path. The user's BTC
is locked on Bitcoin forever.

### Vulnerable sequence (exact production code, cc2cfd78 ~line 794)

```solidity
// AssetRouter.handlePayload()
$.usedPayloads[payload.id] = true;               // CONSUMED FOREVER
_confirmMint($, nonce, recipient, token, amount); // bascule — no pause guard
IBaseLBTC(receipt.toToken).mint(recipient, amount); // REVERTS: MintBurnPaused
```

```solidity
// Mailbox._handle() — silent catch
try IHandler(recipient).handlePayload(payload) { ... }
catch { emit MessageHandleError(...); return (false, ""); }
```

### No recovery path

```
grep "rescue\|recover\|retry\|reset.*usedPayload" AssetRouter.sol → zero results
usedPayloads mapping is never deleted or reset anywhere in the contract
```

### Audit coverage — not previously reported

| Auditor | Report | Scope | Covers this? |
|---|---|---|---|
| Sherlock YB | Jul 2025 | AssetRouter, GMP | No |
| OZ YB | Jul 2025 | AssetRouter, GMP | No |
| Sherlock multi | Apr 2026 | mint/burn pauser role | No |
| OZ multi | Apr 2026 | mint/burn pauser role | No |

Sherlock's Apr 2026 report found L-7: missing `whenMintBurnAllowed` on
`redeemForBtc()`. The mint-side equivalent in `handlePayload()` was not
identified by any of the four relevant auditors.

---

## Why We Did Not Submit

### PoC environment blockers

The mainnet fork PoC never reached all-passing status due to a chain of
environment issues on forge-std v1.1.2 and the ERC-7201 namespaced storage
layout of the deployed proxies:

1. `usedPayloads` is inside an ERC-7201 namespaced struct — no public
   getter exists on the deployed contract. Our slot calculation returned
   wrong values.

2. Bascule `validateThreshold = 0` on mainnet means every synthetic
   payload fails `validateMint` unless reported to the Bascule first.
   We attempted to null out the bascule via `vm.store` but the slot
   calculation was also wrong for the AssetRouter proxy.

3. The `Payload` struct `msgDestinationCaller` field is `address` in
   production but we had it as `bytes32`, causing ABI encoding mismatch
   and a 258-gas revert at the function selector level. Fixed late.

4. Time ran out before all four tests passed cleanly.

### Substantive weakness in the finding

Even if the PoC had passed, Lombard has a strong counter-argument:

> "We control the relayer. We do not deliver messages during a pause
> window. This is an operational procedure, not a code vulnerability."

The relayer is permissionless in theory but in practice Lombard operates
it. They can guarantee no delivery during pauses off-chain. Without a
credible path to force delivery during a pause without Lombard's
cooperation, the finding degrades from High toward Medium or Low.

The correct severity framing would have been:

- **High** if the relayer is truly permissionless and anyone can call
  `deliverAndHandle` with a valid consortium proof
- **Medium** if Lombard can demonstrate operational controls prevent
  delivery during pause windows

We did not verify whether `deliverAndHandle` requires any additional
permission beyond the consortium proof. If it is truly open, the finding
is valid High. If Lombard controls delivery, it is lower.

---

## The Real Lesson — Trust Assumptions in GMP Systems

Cross-chain message delivery involves trust assumptions that are easy
to miss:

```
Bitcoin deposit
    ↓
Consortium signs proof        ← trusted multi-sig
    ↓
Relayer calls deliverAndHandle ← who controls this?
    ↓
Mailbox verifies proof         ← on-chain, trustless
    ↓
AssetRouter.handlePayload      ← our bug is here
    ↓
NativeLBTC.mint                ← guarded by pause
```

If the relayer is permissionless, the attack surface is real.
If the relayer is operated only by Lombard, the operational risk
is present but not a code-level security vulnerability.

**Before submitting GMP-related findings, always verify:**

1. Who can call the message delivery function?
2. Is there any permissioning on the delivery entry point?
3. Can an attacker force delivery independently of the protocol operator?

---

## ERC-7201 Storage Slot Calculation — Hard Lessons

We spent significant time fighting storage slot calculations for the
mainnet fork PoC. Key lessons:

### The formula

```python
# ERC-7201 base slot for namespace "lombardfinance.storage.AssetRouter"
namespace = b"lombardfinance.storage.AssetRouter"
inner = keccak256(namespace)
base = keccak256(inner + b'\x00'*31 + b'\x01') & ~0xff
```

### Verification step we missed

Always verify the computed slot against a KNOWN value before using it:

```bash
# Read mailbox address (known: 0x964677F3...) from storage
cast storage $CONTRACT $COMPUTED_MAILBOX_SLOT --rpc-url $RPC
# If it returns 0x0000...0000, the base slot is wrong
```

We skipped this verification and wasted hours writing to wrong slots.

### The mapping slot formula

```
usedPayloads[id] slot = keccak256(abi.encode(id, base + offset))
```

Where `offset` is the field position in the struct (0-indexed).
`usedPayloads` is at offset 3 in `AssetRouterStorage`.

---

## What We Did Well

- Read the full call chain: Mailbox → AssetRouter → NativeLBTC
- Identified the silent catch in `Mailbox._handle()` independently
- Cross-referenced with Sherlock L-7 (redeem side) to position our
  finding as the symmetric mint-side equivalent
- Confirmed `usedPayloads` is never cleared anywhere in the codebase
- Correctly identified the Bascule as a secondary validation layer

---

## Updated Hunting Checklist

Added to our GMP/cross-chain finding process:

```
Before submitting any GMP message delivery finding:

1. Is the delivery function permissionless? (anyone can call it?)
   YES → finding is valid regardless of operator controls
   NO  → check what permissions are required

2. Who controls message delivery in practice?
   Permissionless relayer → High/Critical severity
   Protocol-operated relayer → operational risk, lower severity

3. Is there a recovery path for failed deliveries?
   No recovery → "permanent lock" argument is valid
   Recovery exists → downgrade severity

4. Verify storage slot calculations against KNOWN values before
   writing vm.store or reading vm.load in fork tests.
```

---

## What to Do Next

The `handlePayload` + mint pause finding is worth revisiting if:

1. Someone can demonstrate `deliverAndHandle` is truly permissionless
   (any address with a valid consortium proof can call it)
2. The Bascule is disabled or bypassed in some configuration
3. A scenario exists where the protocol itself delivers messages during
   a known pause (e.g. automated relayer with no pause-awareness)

For now: move to the next target. The OZ High (ReHypothecationHook DoS)
is still escalated and has cleaner impact. That is the priority.

---

## References

- Lombard Finance repo: github.com/lombard-finance/evm-smart-contracts
- Sherlock L-7 (redeem side): Sherlock_multipauser_bridge_04_26.pdf
- Related closed report: Report ID 77600 (mint/burn ordering)
- ERC-7201 spec: eips.ethereum.org/EIPS/eip-7201
