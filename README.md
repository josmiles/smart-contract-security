# Smart Contract Security — Joseph Kamanja

> Full-stack developer and CyberShujaa-certified Security Analyst transitioning into Smart Contract Auditing.
> This repository is a living record of every vulnerability I study, every challenge I solve, and every audit report I write.

---

## Who This Is For

This is my public learning journal and portfolio. Every folder contains:
- The vulnerable contract (where applicable)
- My exploit
- A written explanation of the vulnerability
- The fix

If you're a protocol looking to hire an auditor — this is my CV.

---

## Repository Structure

```
smart-contract-security/
│
├── ethernaut/                  ← OpenZeppelin's 30-level hacking challenges
│   ├── 01-fallback/
│   ├── 02-fallout/
│   └── ...
│
├── damn-vulnerable-defi/       ← Advanced DeFi-specific challenges
│   ├── 01-unstoppable/
│   └── ...
│
├── audit-reports/              ← Full audit reports (mock + real)
│   ├── mock-audits/
│   └── templates/
│
├── foundry-exploits/           ← Forge test exploits (runnable proof of concepts)
│   ├── src/                   ← Vulnerable contracts
│   ├── test/                  ← Exploit tests
│   └── script/                ← Deployment scripts
│
├── tools-and-references/       ← Slither notes, Foundry cheatsheet, EVM reference
│
├── resources/                  ← Key links, reading list, vulnerability database
│
└── writeups/                   ← Deep-dive writeups on real DeFi hacks
```

---

## Progress Tracker

### Ethernaut
| Level | Name | Vulnerability | Status |
|-------|------|--------------|--------|
| 00 | Hello Ethernaut | Tutorial | ⬜ |
| 01 | Fallback | Fallback function ownership takeover | ✅ |
| 02 | Fallout | Constructor naming bug | ✅ |
| 03 | Coin Flip | Weak randomness (block variables) | ⬜ |
| 04 | Telephone | tx.origin vs msg.sender | ⬜ |
| 05 | Token | Integer underflow (pre-0.8) | ⬜ |
| 06 | Delegation | Delegatecall storage collision | ⬜ |
| 07 | Force | Selfdestruct ETH forcing | ⬜ |
| 08 | Vault | Private variable visibility | ⬜ |
| 09 | King | Denial of service via revert | ⬜ |
| 10 | Reentrancy | Classic reentrancy attack | ✅ |

### Damn Vulnerable DeFi
| Level | Name | Vulnerability | Status |
|-------|------|--------------|--------|
| 01 | Unstoppable | Flash loan griefing | ✅ |
| 02 | Naive Receiver | Unprotected flash loan receiver | ⬜ |
| 03 | Truster | Arbitrary calldata in flash loan | ⬜ |
| 04 | Side Entrance | Flash loan accounting flaw | ⬜ |
| 05 | The Rewarder | Flash loan reward manipulation | ⬜ |
| 06 | Selfie | Governance + flash loan attack | ⬜ |
| 07 | Compromised | Oracle price manipulation | ⬜ |
| 08 | Puppet | AMM price oracle manipulation | ⬜ |

### Audit Reports Written
| Project | Type | Findings | Date |
|---------|------|----------|------|
| — | — | — | — |

### Code4rena Contests
| Protocol | Date | Findings | Earnings |
|----------|------|----------|---------|
| — | — | — | — |

---

## Tools Stack

| Tool | Purpose | Install |
|------|---------|---------|
| Foundry (forge/cast/anvil) | Compile, test, exploit, local chain | `curl -L https://foundry.paradigm.xyz \| bash` |
| Slither | Static analysis / automated vuln detection | `pip install slither-analyzer` |
| Echidna | Property-based fuzzing | GitHub releases |
| Chisel | Solidity REPL | Included in Foundry |
| Cast | CLI blockchain interaction | Included in Foundry |
| Anvil | Local Ethereum node | Included in Foundry |

---

## Vulnerability Classes I'm Studying

- [ ] Reentrancy
- [ ] Integer Overflow/Underflow
- [ ] Access Control
- [ ] Oracle Manipulation
- [ ] Flash Loan Attacks
- [ ] Front-Running / MEV
- [ ] Signature Replay
- [ ] Unsafe Delegatecall
- [ ] Unchecked Return Values
- [ ] Price Manipulation via AMM
- [ ] Logic Errors
- [ ] Griefing / DoS

---

## Resources

See `/resources/reading-list.md` for full list.

Key links:
- [Ethernaut](https://ethernaut.openzeppelin.com)
- [Damn Vulnerable DeFi](https://damnvulnerabledefi.xyz)
- [Solodit](https://solodit.xyz) — real audit findings database
- [Immunefi](https://immunefi.com) — bug bounties
- [Code4rena](https://code4rena.com) — audit contests
- [Rekt News](https://rekt.news) — DeFi hack postmortems
- [SWC Registry](https://swcregistry.io) — Smart Contract Weakness Classification

---

## Contact

Joseph Kamanja · Nairobi, Kenya
- GitHub: [github.com/josmiles](https://github.com/josmiles)
- LinkedIn: [linkedin.com/in/jkamanja](https://www.linkedin.com/in/jkamanja)
- Email: josephkamanja433@gmail.com

> *"Security is not a feature — it's a foundation."*
