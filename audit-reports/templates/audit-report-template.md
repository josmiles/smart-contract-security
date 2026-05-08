# Smart Contract Audit Report

| Field | Details |
|-------|---------|
| Project | Protocol Name |
| Auditor | Joseph Kamanja |
| Date | Date |
| Commit | Git commit hash |
| Version | 1.0 |

---

## Executive Summary

Brief overview of the protocol and overall security posture.

| Severity | Count |
|----------|-------|
| Critical | 0 |
| High | 0 |
| Medium | 0 |
| Low | 0 |
| Informational | 0 |

---

## Scope

Contracts audited:
- contracts/ContractName.sol

---

## Methodology

- Manual code review
- Slither static analysis
- Foundry fuzz testing
- Protocol documentation review

---

## Finding Template

### [F-01] Finding Title

Severity: Critical / High / Medium / Low
Category: Reentrancy / Access Control / Logic Error
Location: contracts/ContractName.sol Line X
Status: Open / Acknowledged / Fixed

#### Description
Clear explanation of the vulnerability.

#### Vulnerable Code
// paste vulnerable snippet here

#### Impact
What can an attacker actually do?

#### Proof of Concept
Step by step exploit or Foundry test.

#### Recommendation
Fixed code and explanation.

---

## Severity Classification

| Severity | Criteria |
|----------|---------|
| Critical | Direct loss of funds, unrestricted minting |
| High | Indirect fund loss, major protocol disruption |
| Medium | Limited fund loss, temporary DoS |
| Low | Best practice violations, minor impact |
| Info | Gas optimizations, code quality |

---

Auditor: Joseph Kamanja
GitHub: github.com/josmiles
Email: josephkamanja433@gmail.com
