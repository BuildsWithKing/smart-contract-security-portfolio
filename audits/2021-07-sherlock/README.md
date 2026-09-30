# Sherlock v1

**Review dates:** 18-30 September 2026

**Review type:** Historical Code4rena practice audit

**Repository:** https://github.com/code-423n4/2021-07-sherlock

**Commit:** `d9c610d2c3e98a412164160a787566818debeae4`

**Original findings:** https://github.com/code-423n4/2021-07-sherlock-findings/issues

**Official report:** https://code4rena.com/reports/2021-07-sherlock

## Files

- [My audit report](report.md)
- [My postmortem and lessons](postmortem.md)

## Results

- **L-1:** Fee-on-transfer and negative-rebasing staking tokens can create an accounting shortfall.
- **L-2:** `tokenUnload()` can revert for ERC-20 tokens whose `approve()` function does not return a boolean.

Both findings are self-assessed Low. L-1 corresponds to an issue rated Medium in the official report. These are retrospective findings and were not submitted to the original contest.
