# Smart Contract Security Portfolio

I am [Michealking](https://github.com/BuildsWithKing), a Solidity developer learning smart contract security through hands-on protocol reviews.

This repository contains my practice audit reports, proofs of concept, and the lessons I learned from each review. Unless I clearly state otherwise, these are learning exercises, not professional audits.

## Reviews

| Protocol | Review type | Date | Results |
| --- | --- | --- | --- |
| [88mph](audits/2021-05-88mph/) | Historical Code4rena practice audit | 7-15 August 2026 | 1 independently reproduced low-severity issue and 1 issue that matched the official report |
| [Yield Protocol v2](audits/2021-08-yield/) | Historical Code4rena practice audit | 26 August-15 September 2026 | 1 self-assessed Medium finding reproduced with Foundry and 1 Low observation |

## How I Review Protocols

1. Understand what the protocol does and which assets are at risk.
2. Identify the users, trusted roles, external protocols, and important assumptions.
3. Trace one important flow from beginning to end.
4. Write down anything suspicious as a hypothesis.
5. Try to prove the hypothesis wrong before reporting it.
6. Use tests or numerical examples when code tracing is not enough.
7. Compare my completed review with the official report and record what I missed.

## Disclaimer

These reports describe the code and commits I reviewed. They are not a guarantee that any protocol is secure.

## Contact

- GitHub: [BuildsWithKing](https://github.com/BuildsWithKing)
