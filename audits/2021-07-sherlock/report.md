## Low 
### [L-1]: Fee-on-transfer and negative-rebasing staking tokens create an accounting shortfall

If governance enables a fee-on-transfer or negative-rebasing token for staking, `PoolOpen::stake` credits the user with the requested `_amount`, even when Sherlock receives less than `_amount`. The recorded pool balance can become larger than the actual token balance.

**Example:** Alice stakes 100 tokens. A 10% transfer fee means Sherlock receives only 90, but it records 100 and mints lock shares based on 100. Later, the system may try to honour 100 worth of claims with only 90 actually received. Other stakers can bear that shortfall, or withdrawals can fail when liquidity is insufficient.

**Recommendation:** 
- For fee-on-transfer tokens, calculate the deposited amount from the balance change and mint shares only for the amount Sherlock actually received. 

```solidity
    uint256 balanceBefore = _token.balanceOf(address(this));
    _token.safeTransferFrom(msg.sender, address(this), _amount);
    uint256 balanceAfter = _token.balanceOf(address(this));

    uint256 amountDeposited = balanceAfter - balanceBefore;

    lock = LibPool.stake(ps, amountDeposited, _receiver);
  }
```

- For negative-rebasing tokens, do not whitelist them unless the pool is redesigned to account for changing balances.

*Official severity:* Medium. I discounted the risk because governance must list the token; judges treated a listed supported asset as a normal assumption.


### [L-2]: `tokenUnload()` is incompatible with ERC20 tokens that return no boolean from `approve()`

`tokenUnload()` calls `_token.approve(address(_native), totalToken)` directly. Some ERC20 tokens return no boolean value from `approve()`. Solidity expects a boolean for this direct interface call, so unloading such a supported token reverts even when the token approval itself succeeds.

**Impact:** Governance cannot complete `tokenUnload()` for that token, which can block the configured asset-removal process.

**Recommendation:** Replace the direct call with `_token.safeApprove(address(_native), totalToken)` from OpenZeppelin `SafeERC20`.
