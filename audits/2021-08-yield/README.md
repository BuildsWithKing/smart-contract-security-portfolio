# Yield Protocol v2

**Review dates:** 26 August-15 September 2026

**Review type:** Historical Code4rena practice audit

**Repository:** https://github.com/code-423n4/2021-08-yield

**Commit:** `4dc46470e616dd0cbd9db9b4742e36c4d809e02c`

**Original findings:** https://github.com/code-423n4/2021-08-yield-findings/issues

**Official report:** https://code4rena.com/reports/2021-08-yield

## Files

- [My audit report](report.md)
- [My postmortem and lessons](postmortem.md)

## Results

- **M-01:** Burning all Strategy shares reduces `cached` and `totalSupply` to zero, preventing subsequent mints and disrupting normal pool unwinding.
- **L-01:** FYTokens pre-transferred in a separate transaction can be consumed by another user's redemption or repayment.

I independently identified M-01 during this retrospective review and reproduced it with Foundry tests against the commit above. L-01 documents a low-risk behavior that requires a user to leave a gap between transferring FYTokens and executing the intended operation.

## Important Note

This was a learning exercise completed after the original 2021 contest. My findings were not submitted to Code4rena or reviewed by the Yield Protocol team, and the severity ratings are my own assessment.
