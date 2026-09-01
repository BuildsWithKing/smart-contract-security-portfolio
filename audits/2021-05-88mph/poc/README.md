# L-01 Rollover Reward-Loss PoC

## Environment

- Upstream: https://github.com/code-423n4/2021-05-88mph
- Commit: `02675d672f7cc17e6bef95830f20443616f92f93`
- Framework: Hardhat / JavaScript

## Reproduction

1. Clone the upstream repository and check out the reviewed commit.
2. Copy [`hardhat_no_fork.js`](hardhat_no_fork.js) into the clone's repository root.
3. Add the test in [`rollover-reward-loss.test.js`](rollover-reward-loss.test.js) to the `rolloverDeposit` context in `test/DInterest.test.js`.
4. Install the upstream dependencies and run the focused test:

```bash
TEST_GREP='preserve unclaimed vested' node node_modules/hardhat/internal/cli/cli.js test --config hardhat_no_fork.js
```

The test intentionally asserts that rollover should preserve the old vest's withdrawable amount. It fails because the amount is positive before rollover and zero afterward.

Observed values during reproduction:

```text
before: 999999699862230
after:  0
```

## Status

The behavior was independently reproduced during this practice review. It was not submitted to or accepted by the original contest or protocol team.
