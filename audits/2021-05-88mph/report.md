# 88mph Audit Report

## Low-Severity Findings

### [L-01] `DInterest::rolloverDeposit` erases unclaimed vested MPH rewards from the old deposit

`rolloverDeposit` creates a new deposit and a new vest for the new `depositID`, while the old vest remains tied to the old deposit whose `virtualTokenTotalSupply` is reduced to zero.

Users who roll over instead of withdrawing first can permanently lose claimable MPH from the old vest because the old vest remains linked to a deposit whose virtual supply has been zeroed.

#### Root Cause

`rolloverDeposit()` at line 998 fully withdraws the old deposit, which reduces the old deposit's `virtualTokenTotalSupply` to zero at line 1159. `Vesting02::getVestWithdrawableAmount` computes withdrawable rewards from the old deposit's current `virtualTokenTotalSupply` at line 187, so after rollover, the old vest returns zero.

#### Proof of Concept

Before rollover, `Vesting02::getVestWithdrawableAmount(1)` returned `999999699862230`.

After rollover, it returned `0`.

```javascript
it("should preserve unclaimed vested MPH from the old deposit after rollover", async function() {
  // Wait 1 year (maturation time)
  await moneyMarketModule.timePass(1);

  const before = BigNumber(
    await baseContracts.vesting02.getVestWithdrawableAmount(Base.num2str(1))
  );
  assert(before.gt(0), "old vest should have claimable MPH before rollover");

  const blockNow = await Base.latestBlockTimestamp();
  await baseContracts.dInterestPool.rolloverDeposit(
    Base.num2str(1),
    Base.num2str(blockNow + Base.YEAR_IN_SEC),
    { from: acc0 }
  );

  const after = BigNumber(
    await baseContracts.vesting02.getVestWithdrawableAmount(Base.num2str(1))
  );
  Base.assertEpsilonEq(
    after,
    before,
    "rollover erased unclaimed vested MPH from old deposit"
  );
});
```

#### Recommendation

Snapshot or withdraw/update the old vest before reducing the old deposit's `virtualTokenTotalSupply`, or carry the unclaimed vested amount into the new vest.

### [L-02] `EMAOracle::updateAndQuery` can revert when the money-market income index decreases

`DInterest::deposit` calls `DInterest::calculateInterestAmount()`, which calls `EMAOracle::updateAndQuery()`. This function subtracts `_lastIncomeIndex` from `newIncomeIndex` without first verifying that `newIncomeIndex` is greater than or equal to `_lastIncomeIndex`.

If `moneyMarket.incomeIndex()` returns a value lower than `_lastIncomeIndex`, `DInterest::deposit`, `DInterest::rolloverDeposit`, and every other function that calls `DInterest::calculateInterestAmount()` can revert.

#### Root Cause

```solidity
uint256 newIncomeIndex = moneyMarket.incomeIndex();
uint256 incomingValue =
    (newIncomeIndex - _lastIncomeIndex).decdiv(_lastIncomeIndex) /
    timeElapsed;
```

#### Recommendation

Verify that `newIncomeIndex` is greater than or equal to `_lastIncomeIndex` before performing the subtraction. If it is not, revert with a clear error or add a recovery path for a decreased money-market income index.

```solidity
require(newIncomeIndex >= _lastIncomeIndex, "EMAOracle: income index decreased");

uint256 incomingValue =
    (newIncomeIndex - _lastIncomeIndex).decdiv(_lastIncomeIndex) /
    timeElapsed;
```

**Status:** This issue is also present in the official Code4rena report as L-03.
