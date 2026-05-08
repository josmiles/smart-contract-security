# Ethernaut - Level 01: Fallback

| Field | Details |
|-------|---------|
| Platform | Ethernaut by OpenZeppelin |
| Level | 01 |
| Vulnerability | Fallback Function Ownership Takeover |
| Severity | Critical |
| Status | Solved |

## Objective
Claim ownership of the contract and reduce its balance to 0.

## Root Cause
The receive() fallback function transfers ownership to any caller who:
1. msg.value > 0 - sends any ETH
2. contributions[msg.sender] > 0 - has contributed before

## Proof of Concept
1. contribute(0.0001 ETH) - satisfy contributions check
2. send ETH directly - trigger receive() - steal ownership
3. withdraw() - drain contract

## Fix
Remove owner = msg.sender from receive() function.
Use a dedicated claimOwnership() with proper guards.

## Status
- Solved on Ethernaut
- Foundry exploit written and passing
- Added to GitHub
