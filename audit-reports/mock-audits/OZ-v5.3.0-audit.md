# Audit Report - OpenZeppelin Contracts v5.3.0

| Field | Details |
|-------|---------|
| Auditor | Joseph Kamanja |
| Target | OpenZeppelin Contracts v5.3.0 |
| Commit | e4f70216 |
| Date | 2026-05-09 |

---

## [F-01] SuperQuorum Equal to Quorum Bypasses Early Execution Protection

| Property | Value |
|----------|-------|
| Severity | Medium |
| Category | Logic Error / Spec Mismatch |
| Location | GovernorVotesSuperQuorumFraction.sol Line 103 |
| Status | Open |

### Description

The validation check uses strict less-than instead of less-than-or-equal:

    if (newSuperQuorumNumerator < quorumNumerator) {
        revert GovernorInvalidSuperQuorumTooSmall(...);
    }

The NatSpec for the error says: smaller OR EQUAL should be invalid.
But the code allows superQuorumNumerator == quorumNumerator to pass.

### Impact

When superQuorum equals quorum, the super quorum feature is neutralised.
Any proposal meeting regular quorum automatically meets super quorum.
Proposals advance to Succeeded before deadline with no extra protection.

### Proof of Concept

1. Deploy with quorumNumerator = 40, superQuorumNumerator = 40
2. Validation passes: 40 < 40 = false, no revert
3. Any proposal with 40% FOR votes immediately succeeds early
4. Super quorum provides zero additional barrier over regular quorum

### Fix

    // BEFORE
    if (newSuperQuorumNumerator < quorumNumerator) {

    // AFTER
    if (newSuperQuorumNumerator <= quorumNumerator) {

This aligns code with NatSpec which states equal is also invalid.

### References
- GovernorVotesSuperQuorumFraction.sol Line 103
- Error NatSpec Line 30
