# Damn Vulnerable DeFi - Level 01: Unstoppable

| Field | Details |
|-------|---------|
| Platform | Damn Vulnerable DeFi |
| Level | 01 |
| Vulnerability | Accounting Invariant Violation |
| Severity | High |
| Status | Solved |
| Category | Denial of Service |

## Objective
Stop the vault from offering flash loans permanently.

## Root Cause
The vault tracks token balance two ways:
- totalSupply: manually tracked via deposit()
- asset.balanceOf(address(this)): real ERC20 balance

Flash loan asserts these are always equal:
if (convertToShares(totalSupply) != totalAssets()) revert InvalidBalance();

ERC20 tokens can be sent directly to any address bypassing deposit().
One direct transfer breaks this assertion forever.

## Proof of Concept
// Send 1 token directly - bypasses deposit()
await token.transfer(vault.address, 1)

// Now totalSupply != balanceOf
// Every flashLoan() call reverts forever

## Attack Flow
Attacker sends 1 token directly to vault
balanceOf increases but totalSupply unchanged
assertion fails on every flashLoan() call
protocol permanently bricked

## Fix
Change strict equality to greater than or equal:
if (convertToShares(totalSupply) > totalAssets()) revert InvalidBalance();

## Key Takeaways
Never assume balanceOf(address(this)) equals internal accounting.
Tokens can always be sent directly to any address.

Audit grep:
grep -n "balanceOf(address(this))" contracts/*.sol

## References
- SWC-132: Unexpected Ether Balance

## Status
- Solved on Damn Vulnerable DeFi
- Foundry test written
- Added to GitHub
