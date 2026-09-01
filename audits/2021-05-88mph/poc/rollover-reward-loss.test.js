// Add this regression test to the rolloverDeposit context in test/DInterest.test.js.
it("should preserve unclaimed vested MPH from the old deposit after rollover", async function() {
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
