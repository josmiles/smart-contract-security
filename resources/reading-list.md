# Reading List & Resources

Everything needed to go from zero to paid smart contract auditor.
Work through these in order.

---

## Phase 1 — Foundations

### Must-Read Docs
- [ ] [Solidity Security Considerations](https://docs.soliditylang.org/en/latest/security-considerations.html) — official Solidity security guide
- [ ] [SWC Registry](https://swcregistry.io) — Smart Contract Weakness Classification (the CVE database for smart contracts)
- [ ] [Ethereum Yellow Paper](https://ethereum.github.io/yellowpaper/paper.pdf) — EVM internals (deep, but essential eventually)

### Must-Do Challenges
- [ ] [Ethernaut](https://ethernaut.openzeppelin.com) — 30 levels, start here
- [ ] [Capture The Ether](https://capturetheether.com) — classic challenges
- [ ] [Damn Vulnerable DeFi](https://damnvulnerabledefi.xyz) — DeFi-specific, harder

---

## Phase 2 — Real Audit Reports (Read These)

### Cyfrin Audits
- [ ] [cyfrin.io/audits](https://cyfrin.io/audits) — Patrick Collins' firm, well-written reports

### Trail of Bits
- [ ] [github.com/trailofbits/publications](https://github.com/trailofbits/publications) — industry gold standard

### OpenZeppelin
- [ ] [blog.openzeppelin.com/security-audits](https://blog.openzeppelin.com/security-audits) — excellent write-ups

### Spearbit
- [ ] [github.com/spearbit/portfolio](https://github.com/spearbit/portfolio) — top-tier reports

---

## Phase 3 — Real Finding Research

### Solodit
- [solodit.xyz](https://solodit.xyz) — searchable database of every contest finding
- **Daily habit:** Read 5 findings every morning
- Filter by: High severity, Reentrancy, Access Control

### Rekt News (DeFi Hack Postmortems)
- [rekt.news](https://rekt.news)
- Key ones to study:
  - [ ] The DAO (2016) — Reentrancy, $60M
  - [ ] Poly Network (2021) — Access control, $611M
  - [ ] Ronin Bridge (2022) — Validator compromise, $625M
  - [ ] Nomad Bridge (2022) — Logic error, $190M
  - [ ] Euler Finance (2023) — Donation attack, $197M
  - [ ] Cream Finance (2021) — Flash loan + reentrancy, $130M

---

## Phase 4 — Earning Platforms

### Contest Platforms
- [Code4rena](https://code4rena.com) — biggest, most competitive
- [Sherlock](https://sherlock.xyz) — more beginner-friendly judging
- [Codehawks](https://codehawks.com) — Cyfrin's platform

### Bug Bounties
- [Immunefi](https://immunefi.com) — live protocol bounties
- [HackenProof](https://hackenproof.com)

---

## Phase 5 — Key Protocols to Study (Source Code)

Reading good code is as important as reading bad code.

- [ ] [OpenZeppelin Contracts](https://github.com/OpenZeppelin/openzeppelin-contracts) — the standard library, read everything
- [ ] [Uniswap V3](https://github.com/Uniswap/v3-core) — complex but important
- [ ] [Aave V3](https://github.com/aave/aave-v3-core) — you already know the flash loan interface
- [ ] [Compound V3](https://github.com/compound-finance/comet)

---

## Tools

| Tool | Link | Purpose |
|------|------|---------|
| Foundry | [getfoundry.sh](https://getfoundry.sh) | Primary testing framework |
| Slither | [github.com/crytic/slither](https://github.com/crytic/slither) | Static analysis |
| Echidna | [github.com/crytic/echidna](https://github.com/crytic/echidna) | Fuzzer |
| Mythril | [github.com/ConsenSys/mythril](https://github.com/ConsenSys/mythril) | Symbolic execution |
| Alchemy | [alchemy.com](https://alchemy.com) | RPC provider (free tier) |
| Etherscan | [etherscan.io](https://etherscan.io) | Read live contract source |

---

## Twitter / X — Accounts to Follow

These people post about live vulnerabilities, contest findings, and security research:

- @PatrickAlphaC — Cyfrin founder, best Solidity teacher
- @trust__90 — top solo auditor
- @bytes032 — audit contest winner
- @0xOwenThurm — Cyfrin auditor
- @PwnedNoMore — security researcher
- @samczsun — top white-hat, researcher at Paradigm

---

## YouTube

- [ ] [Patrick Collins — Foundry Course (2024)](https://www.youtube.com/watch?v=umepbfKp5rI) — 27 hours, the gold standard
- [ ] [Andy Li — Smart Contract Auditing](https://www.youtube.com/c/andyli) — audit-specific content
- [ ] [Owen Thurm — Security content](https://www.youtube.com/@0xOwenThurm)
