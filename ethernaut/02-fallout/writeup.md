# Level 02 — Fallout

## Contract

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import '@openzeppelin/contracts/math/SafeMath.sol';

contract Fallout {
  using SafeMath for uint256;
  mapping (address => uint) allocations;
  address payable public owner;

  /* constructor */
  function Fal1out() public payable {
    owner = msg.sender;
    allocations[owner] = msg.value;
  }

  // ... rest of contract
}
```

---

## Objective
Claim ownership of the contract.

---

## Vulnerability

**Type:** Constructor Naming Bug (Typo)
**Severity:** Critical
**SWC:** SWC-118 (Incorrect Constructor Name)

### What's Wrong

In Solidity versions before 0.5.0, constructors were defined as functions with the **same name as the contract**. The contract is named `Fallout` but the constructor is named `Fal1out` (with a number **1** instead of letter **l**).

This means `Fal1out()` is NOT a constructor — it's a regular public function that anyone can call at any time to claim ownership.

### Root Cause
Human typo + old Solidity constructor syntax. This is why Solidity 0.5.0+ introduced the `constructor()` keyword — to eliminate this entire bug class.

---

## Exploit

```javascript
// Anyone can call this — it's just a public function now
await contract.Fal1out()

// Verify
await contract.owner() // returns your address
```

---

## Fix

```solidity
// Old (vulnerable) — function name must match contract name exactly
contract Fallout {
    function Fal1out() public payable { ... } // TYPO — not a constructor!
}

// Modern fix — use constructor() keyword (Solidity 0.5.0+)
contract Fallout {
    constructor() public payable {
        owner = msg.sender;
    }
}
```

---

## Key Lesson

> Always use the `constructor()` keyword in modern Solidity. Never define constructors as named functions. One character typo = complete ownership loss.

**In audits: search for functions that look like constructors but aren't. Grep for function names matching the contract name.**

---

## Status
- [x] Solved on Ethernaut
- [x] Foundry exploit written
- [x] Added to GitHub
