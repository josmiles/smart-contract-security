# Ethernaut - Level 02: Fallout

| Field | Details |
|-------|---------|
| Platform | Ethernaut by OpenZeppelin |
| Level | 02 |
| Vulnerability | Constructor Naming Bug |
| Severity | Critical |
| Status | Solved |

## Objective
Claim ownership of the contract.

## Root Cause
In Solidity before 0.5.0, constructors were defined as functions with
the same name as the contract. The contract is named Fallout but the
constructor is named Fal1out (number 1 instead of letter l).

This means Fal1out() is NOT a constructor - it is a regular public
function anyone can call at any time to claim ownership.

## Proof of Concept
await contract.Fal1out()
await contract.owner() // returns your address

## Fix
Use the constructor() keyword - available since Solidity 0.5.0:

constructor() public payable {
    owner = msg.sender;
}

## Key Takeaways
Always use constructor() keyword in modern Solidity.
One character typo = complete ownership loss.

Audit pattern - search for functions matching the contract name:
grep -n "function Fal" contracts/*.sol

## References
- SWC-118: Incorrect Constructor Name

## Status
- Solved on Ethernaut
- Foundry exploit written
- Added to GitHub
