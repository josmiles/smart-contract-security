# Smart Contract Audit Report

**Project:** [Protocol Name]  
**Auditor:** Joseph Kamanja  
**Date:** [Date]  
**Commit Hash:** [Git commit of audited code]  
**Report Version:** 1.0

---

## Executive Summary

[2–3 sentence overview of the protocol, what it does, and the overall security posture found during the audit.]

**Total Findings:**

| Severity | Count |
|----------|-------|
| 🔴 Critical | 0 |
| 🟠 High | 0 |
| 🟡 Medium | 0 |
| 🔵 Low | 0 |
| ⚪ Informational | 0 |

---

## Scope

**Contracts Audited:**
- `contracts/ContractName.sol`

**Out of Scope:**
- [List anything not reviewed]

**Lines of Code:** [Number]

---

## Methodology

This audit was conducted using a combination of:
- Manual code review (primary method)
- Slither static analysis
- Foundry fuzz testing
- Review of protocol documentation and test suite

---

## Findings

---

### [F-01] — [Finding Title]

**Severity:** 🔴 Critical / 🟠 High / 🟡 Medium / 🔵 Low / ⚪ Informational  
**Category:** Reentrancy / Access Control / Logic Error / etc.  
**Location:** `contracts/ContractName.sol` — Line [X]  
**Status:** Open / Acknowledged / Fixed

#### Description

[Clear explanation of the vulnerability. What is the code doing? What should it be doing? Why is this a problem?]

#### Vulnerable Code

```solidity
// Line X — ContractName.sol
function vulnerableFunction() public {
    // highlight the problematic line
}
```

#### Impact

[What can an attacker actually do with this? Be specific — "drain all ETH", "steal any user's tokens", "permanently brick the protocol".]

#### Proof of Concept

```solidity
// Step-by-step exploit
// 1. Attacker calls X with parameters Y
// 2. Contract executes Z
// 3. Attacker gains A at expense of B

// Foundry test demonstrating the exploit:
function testExploit() public {
    // ...
}
```

Or steps:
1. Deploy `AttackerContract` targeting `VulnerableContract`
2. Call `AttackerContract.attack()` with 1 ETH
3. Observe contract balance drained to 0

#### Recommendation

```solidity
// Fixed code
function fixedFunction() public {
    // Show the corrected implementation
}
```

[Explain why this fix works.]

---

### [F-02] — [Finding Title]

[Repeat structure above for each finding]

---

## Informational Findings

### [I-01] — [Title]

**Category:** Gas Optimization / Code Quality / Best Practice  
**Location:** `contracts/ContractName.sol` — Line [X]

[Brief explanation. These don't affect security but improve the codebase.]

---

## Tools Used

| Tool | Version | Purpose |
|------|---------|---------|
| Slither | 0.10.x | Static analysis |
| Foundry | Latest | Exploit testing + fuzzing |
| Solidity | 0.8.19 | Compiler |

---

## Disclaimer

This audit was performed on the code commit specified above. It does not guarantee the absence of vulnerabilities. Smart contract audits reduce risk but do not eliminate it. The auditor is not responsible for any losses arising from undetected vulnerabilities.

---

*Auditor: Joseph Kamanja — josephkamanja433@gmail.com*  
*GitHub: github.com/josmiles*
