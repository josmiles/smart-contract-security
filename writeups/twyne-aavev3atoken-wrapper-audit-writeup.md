# Writeup — Twyne Protocol AaveV3ATokenWrapper Full Attack Surface Review

| Field | Details |
|-------|---------|
| Auditor | Joseph Kamanja |
| Protocol | Twyne Protocol |
| Contracts | src/AaveV3ATokenWrapper.sol, src/CustomERC4626StataTokenUpgradeable.sol |
| Commit | 0aa37b02fca27025a049daf0d7ec31b94f1810eb (twyne-contracts-v1 tag: 1.0.5) |
| Wrapper repo | github.com/0xTwyne/aave-v3-aToken-wrapper (main branch) |
| Platform | Immunefi bug bounty — max $50,000 USDC Critical / $10,000 High |
| Date | May 14, 2026 |
| Report ID | Not submitted — no exploitable vulnerability found |
| Status | Engagement closed, clean |
| Severity Assessed | N/A |

---

## Scope of This Session

This session covered the only remaining uninspected attack surface from
the prior engagement sessions: the `AaveV3ATokenWrapper` custom
implementation, deployed separately from the main `twyne-contracts-v1`
repo at:

- Proxy: `0xFaBA8f777996C0C28fe9e6554D84cB30ca3e1881` (wstETH wrapper)
- Impl: `0xff8cbf0bb4274cf82c23779ab04978d631a0a34e`

All other in-scope contracts (`CollateralVaultBase.sol`,
`AaveV3CollateralVault.sol`, `EulerCollateralVault.sol`,
`VaultManager.sol`, `AaveV3TeleportOperator.sol`,
`CollateralVaultFactory.sol`, `AaveV3Wrapper.sol`) were fully reviewed
in prior sessions and are not re-analyzed here.

The two custom Twyne functions added on top of the upstream Aave
StataTokenV2 base were the primary targets:

- `rebalanceATokens_CV(uint shares)` — adjusts aToken delegation to a
  CollateralVault
- `burnShares_CV(uint shares)` — burns wrapper shares after external
  Aave liquidation

---

## What We Analyzed

### `rebalanceATokens_CV(uint shares)` — full trace

```solidity
// AaveV3ATokenWrapper.sol
function rebalanceATokens_CV(uint shares) external onlyCV whenNotPaused {
    IAToken _aToken = IAToken(aToken());
    uint actualScaledBalance = _aToken.scaledBalanceOf(msg.sender);

    if (shares < actualScaledBalance) {
        _aToken.transferFrom(msg.sender, address(this),
            _convertToAssets(actualScaledBalance - shares, Math.Rounding.Floor));
    } else if (shares > actualScaledBalance) {
        _aToken.transfer(msg.sender,
            _convertToAssets(shares - actualScaledBalance, Math.Rounding.Floor));
    }
}
```

Called from `AaveV3CollateralVault._handleExcessCredit()`. The `shares`
argument is `totalAssetsDepositedOrReserved` — a tracked internal
accounting variable bounded by the vault's own deposit/reserve logic.

```solidity
// CustomERC4626StataTokenUpgradeable.sol
function _convertToAssets(uint256 shares, Math.Rounding rounding)
    internal view virtual override returns (uint256) {
    return shares.mulDiv(_rate(), RAY, rounding);   // scaledBalance → nominal aToken
}

function _rate() internal view returns (uint256) {
    return POOL.getReserveNormalizedIncome(asset()); // Aave liquidity index, RAY units
}
```

Unit relationship: `scaledBalance * liquidityIndex / RAY = nominal aToken balance`.
`transferFrom`/`transfer` on Aave aTokens operates on nominal balances.
The conversion is correct.

### `burnShares_CV(uint shares)` — full trace

```solidity
// AaveV3ATokenWrapper.sol
function burnShares_CV(uint shares) external onlyCV {
    _burn(msg.sender, shares);
}
```

Called from `AaveV3CollateralVault.handleExternalLiquidation()` after
Aave forcibly removes aTokens from the vault's balance. Burns the
corresponding wrapper shares so `totalSupply` (and therefore
`totalAssets`) correctly reflects the reduced backing.

```solidity
// totalAssets() — NOT aToken.balanceOf(address(this))
function totalAssets() public view override returns (uint256) {
    return _convertToAssets(totalSupply(), Math.Rounding.Floor);
}
```

`totalAssets` tracks `totalSupply * rate / RAY`, not the direct aToken
custody balance. After `burnShares_CV`, `totalSupply` decreases, which
correctly contracts `totalAssets`. Direction is right.

---

## Attack Vectors Evaluated

### Vector A — Inflated `shares` draining LP aTokens via `rebalanceATokens_CV`

**Hypothesis:** A caller passes an inflated `shares` value into
`rebalanceATokens_CV`, causing the wrapper to push more aTokens to the
vault than the vault is entitled to, draining LP funds.

**Verdict: CLEAR.**

The `onlyCV` modifier gates the function:

```solidity
modifier onlyCV {
    require(collateralVaultFactory.isCollateralVault(msg.sender), NotCollateralVault());
    _;
}
```

`isCollateralVault` is set to `true` only inside
`CollateralVaultFactory.deployCollateralVault()`, which is owner-only.
There is no permissionless path to register an attacker-controlled
address. Even for a legitimate vault, `shares` originates from
`totalAssetsDepositedOrReserved`, an internal accounting variable the
attacker cannot freely manipulate without first depositing real
collateral.

```
grep "isCollateralVault\[" CollateralVaultFactory.sol
→ written in deployCollateralVault() only, owner-gated, no setter
```

### Vector B — Share/aToken mismatch allowing double-spend via `burnShares_CV`

**Hypothesis:** The `shares` argument to `burnShares_CV` does not
correctly correspond to the aTokens seized, leaving wrapper shares
outstanding against backing that no longer exists — or burns more than
the seized amount, destroying LP value.

**Verdict: CLEAR.**

The share amount is computed inside `handleExternalLiquidation()` using
the same `_convertToShares` path (inverse of `_convertToAssets`).
Both use `_rate()` — the same live liquidity index — so the
round-trip is consistent. OpenZeppelin's `_burn` also reverts on
underflow, so burning more than the vault holds simply reverts; it
cannot corrupt state.

`handleExternalLiquidation()` accounting was reviewed and signed off in
the prior session as correct, with bad debt handled by design and noted
explicitly in Twyne's known issues list.

### Vector C — Reentrancy during aToken transfer in `rebalanceATokens_CV`

**Hypothesis:** `_aToken.transfer(msg.sender, ...)` triggers a callback
that re-enters the wrapper in an inconsistent intermediate state.

**Verdict: CLEAR.**

Aave V3 aTokens are not ERC-777 tokens and implement no `tokensReceived`
or `tokensToSend` hooks. There is no external call that creates a
reentrancy window during `transfer` or `transferFrom`. The
`CustomERC4626StataTokenUpgradeable` base already documents this
analysis in its own `_deposit` and `_withdraw` implementations, which
were inherited unchanged.

### Vector D — `isCollateralVault` access control bypass

**Hypothesis:** Some path causes `isCollateralVault` to return `true`
for an attacker-controlled address without going through the
owner-gated `deployCollateralVault()`.

**Verdict: CLEAR.**

```
grep -n "isCollateralVault" CollateralVaultFactory.sol
→ Line 89:  mapping(address => bool) public isCollateralVault;
→ Line 134: isCollateralVault[vault] = true;   ← inside deployCollateralVault()
→ Line 45:  function deployCollateralVault(...) external onlyOwner
→ No other writes to isCollateralVault anywhere in the codebase
```

No proxy upgrade backdoor, no `setCollateralVault(address)` admin
shortcut, no CREATE2 collision surface. The mapping is a simple boolean
written in exactly one place.

### Vector E — `skim()` arbitrary receiver minting

**Hypothesis:** `skim(address receiver)` is callable by anyone with an
arbitrary `receiver`, enabling an attacker to mint wrapper shares to
themselves.

**Verdict: CLEAR — no profit path.**

```solidity
function skim(address receiver) external {
    IERC20 __asset = IERC20(asset());
    uint256 assets = __asset.balanceOf(address(this));
    uint256 shares = _convertToShares(assets, Math.Rounding.Floor);
    require(shares > 0, StaticATokenInvalidZeroShares());
    POOL.supply(address(__asset), assets, address(this), 0);
    _mint(receiver, shares);
}
```

The attacker must first transfer the underlying asset to the wrapper
(net cost = `assets`), then call `skim` to convert it into shares at
the current exchange rate (net value received = `assets * rate / RAY`
expressed as wrapper shares, redeemable for the same value). Zero
profit. This is intentional recovery logic for accidentally-sent tokens.

### Vector F — Rounding direction

**Hypothesis:** `Math.Rounding.Floor` in either branch of
`rebalanceATokens_CV` consistently favors an attacker over time.

**Verdict: CLEAR.**

Pull branch (excess aTokens in vault): `Floor` rounds down — wrapper
pulls back *slightly less* than owed. Dust stays with the vault, not an
attacker. Push branch (deficit): `Floor` rounds down — wrapper pushes
*slightly less* aToken than the exact target. Conservative for LP
holders. Both directions protect the wrapper and LP; no accumulating
advantage for any attacker.

---

## Audit Coverage Confirmation

| Auditor | Report | Scope | Covers wrapper custom fns? |
|---|---|---|---|
| Spearbit | pre-launch | twyne-contracts-v1 | Not in scope (separate repo) |
| Internal | tag 1.0.5 | twyne-contracts-v1 | Not in scope (separate repo) |

The wrapper repo (`aave-v3-aToken-wrapper`) is deployed separately and
was only added to the Immunefi scope page as an explicit line item. No
prior public audit report covers `burnShares_CV` or
`rebalanceATokens_CV`. Both functions are genuinely novel Twyne
additions on top of upstream Aave StataTokenV2.

---

## Why There Is Nothing to Submit

The two custom functions have a very small, well-bounded attack surface:

1. Both are gated behind `onlyCV` which cannot be bypassed without
   compromising the factory owner.
2. The math in `rebalanceATokens_CV` is a correct scaled ↔ nominal
   aToken conversion using the live Aave liquidity index.
3. `burnShares_CV` delegates entirely to OZ `_burn`, which is
   underflow-safe.
4. No external call in either function creates an observable intermediate
   state for reentrancy.
5. Rounding is conservative in all cases.

The only theoretical risk surface — a legitimate CollateralVault calling
`rebalanceATokens_CV` with an incorrect `shares` value — is not an
external attack; it would require the vault's own internal accounting to
be corrupted first. That accounting (`totalAssetsDepositedOrReserved`)
was reviewed and found correct in prior sessions.

---

## The Real Lesson — Separated Repo Attack Surfaces

The wrapper being in a different GitHub repo than the main protocol
contracts is an easy place to lose scope coverage. The Immunefi page
listed it explicitly but with no source path — only deployed addresses
and the function names `burnShares_CV` and `rebalanceATokens_CV`.

```
Immunefi scope page
    ↓
"AaveV3ATokenWrapper (proxy): 0xFaBA8..."
    ↓
No source link — must find repo independently
    ↓
github.com/0xTwyne/aave-v3-aToken-wrapper   ← separate from main repo
    ↓
src/AaveV3ATokenWrapper.sol
src/CustomERC4626StataTokenUpgradeable.sol  ← base layer, also custom
```

An auditor who only cloned `twyne-contracts-v1` and read the Immunefi
page shallowly would miss this entire contract. The custom functions
would appear only as external calls from `AaveV3CollateralVault` to an
opaque address. **Always resolve every deployed address in scope to its
source, even if the source is not linked.**

**Before closing any engagement with deployed contract addresses in scope:**

1. For every address on the scope page, find and read the source.
2. If the source is in a different repo, clone that repo separately.
3. Pay specific attention to functions the main contracts call on those
   addresses — those call sites are the interface and the primary attack
   surface.
4. Confirm any custom additions on top of audited upstream bases
   (StataTokenV2 here) — the upstream is not the target, the delta is.

---

## ERC4626 Wrapper Math — Reference

For future engagements involving aToken wrappers, the unit relationships
that matter:

```
scaledBalance  = aToken balance at time of last index update
nominalBalance = scaledBalance * liquidityIndex / RAY   (grows over time)

_convertToAssets(scaledDelta, Floor):
    = scaledDelta * POOL.getReserveNormalizedIncome(asset()) / 1e27
    → returns nominalBalance delta (what you pass to aToken.transfer)

_convertToShares(nominalDelta, Floor):
    = nominalDelta * 1e27 / POOL.getReserveNormalizedIncome(asset())
    → returns scaledBalance delta (what you compare to scaledBalanceOf)
```

The invariant the wrapper maintains:
```
sum(scaledBalanceOf(vault_i) for all vaults)
  + scaledBalanceOf(wrapper_address)
= totalSupply_of_wrapper_shares
```

Any function that moves aTokens to/from a vault must move the same
scaled-unit quantity of wrapper shares. `rebalanceATokens_CV` does this
correctly. `burnShares_CV` is called only when aTokens are seized
externally (breaking the invariant from outside), and it restores
accounting by burning the orphaned shares.

---

## What We Did Well

- Fetched both source files directly from the wrapper repo before
  analyzing — did not rely on ABI-only or bytecode analysis.
- Traced every call path: `_handleExcessCredit` → `rebalanceATokens_CV`
  and `handleExternalLiquidation` → `burnShares_CV`.
- Verified `isCollateralVault` write sites with grep before ruling out
  the access control bypass.
- Checked `totalAssets()` implementation — confirmed it tracks
  `totalSupply * rate`, not direct aToken custody, which is the key
  to understanding why `burnShares_CV` correctly restores the invariant.
- Confirmed rounding direction for both branches of `rebalanceATokens_CV`.
- Did not submit a non-finding.

---

## Updated Hunting Checklist

Added to our ERC4626 wrapper / aToken wrapper review process:

```
For any ERC4626 wrapper with custom protocol-gated functions:

1. What is the access control on each custom function?
   onlyOwner / onlyRole → check if role is privileged enough to matter
   onlyCV / protocol-gated → check if that gate can be bypassed

2. Is the unit math correct?
   scaledBalance → nominal aToken: multiply by liquidityIndex / RAY
   nominal aToken → scaledBalance: multiply by RAY / liquidityIndex
   Check _convertToAssets and _convertToShares match this exactly.

3. Does totalAssets() track actual custody or derived from totalSupply?
   Custody-based → external aToken movements change it without burning
   Supply-based   → only mint/burn changes it; externally seized tokens
                     must be manually reconciled via burnShares_CV etc.

4. After any external custody change, is there exactly one function
   that reconciles accounting? Is it callable without the reconcile?
   No reconcile path → accounting diverges permanently
   Reconcile exists → check it burns/mints the correct amount

5. What does the upstream base do vs. the custom delta?
   Read upstream (StataTokenV2, StataToken, etc.) separately.
   The audit target is the custom additions only. The upstream
   is audited; the delta is not.
```

---

## What to Do Next

The Twyne engagement is closed with a clean result. No submittable
finding exists in any in-scope contract at commit 0aa37b02.

Priority queue:
- OZ High (ReHypothecationHook DoS) — still escalated, cleaner impact,
  next in queue.
- Any new Immunefi listings with EVC/EVK-based protocols — the Euler
  integration patterns reviewed here transfer directly.

---

## References

- Twyne contracts repo: github.com/0xTwyne/twyne-contracts-v1 (tag 1.0.5)
- Wrapper repo: github.com/0xTwyne/aave-v3-aToken-wrapper
- Immunefi bounty page: immunefi.com/bug-bounty/twyne/information/
- AaveV3ATokenWrapper proxy: 0xFaBA8f777996C0C28fe9e6554D84cB30ca3e1881
- AaveV3ATokenWrapper impl: 0xff8cbf0bb4274cf82c23779ab04978d631a0a34e
- Upstream base: Aave StataTokenV2 (aave-v3/extensions/stata-token/StataTokenV2.sol)
- ERC-7201 spec: eips.ethereum.org/EIPS/eip-7201
