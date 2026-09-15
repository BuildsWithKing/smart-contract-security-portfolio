## [M-01] Burning all strategy shares zeros cached and totalSupply, preventing future mints and normal pool unwinding

## Summary

After the final holder withdraws, subsequent mints revert because `Strategy::mint()` divides by the zero cached value. Furthermore, without Pool LP tokens, `Strategy::endPool()` cannot obtain assets from `Pool::burn()` to repay the outstanding vault debt.

## Root Cause

This issue occurs because `Strategy::burn` permits `cached` and `totalSupply` to reach zero, whereas `Strategy::mint` lacks a zero-supply initialization branch. 

## Impact

`Medium` This finding's impact is medium because it can cause the contract to become unusable if the final strategy share holder burns all outstanding shares. 

After the full burn, `Strategy::endPool()` reverts because the Strategy has no Pool LP tokens from which to obtain repayment assets.

The damage is on the availability of the Strategy contract, not user funds: reaching `cached == 0` requires the final burner to hold 100% of the supply, so every depositor has already withdrawn their funds - no principal is lost. However, the strategy becomes unusable for future deposits, and the vault debt remains outstanding. The protocol's lifecycle is disrupted `endPool()` - `setNextPool()` - `startPool()`. 

Transferring LP tokens back to the strategy does not restore minting (second PoC).

## PoC
Run the test with the following command:

```bash
forge test --mt testMintAndEndPool_RevertsWhenAllSharesAreBurned -vvvvv
forge test --mt testPoolLPTransferToStrategy_DontRestoreStrategy -vvvvv 
```
<Details>
<summary>Code </summary>

```solidity
    // Test to verify mint and endPool reverts. 
    function testMintAndEndPool_RevertsWhenAllSharesAreBurned() public {
        vm.prank(user);
        strategy.startPool();
        assertGt(strategy.cached(), 0);
        assertEq(strategy.cached(), strategy.balanceOf(user));

        vm.startPrank(user);
        strategy.transfer(address(strategy), strategy.balanceOf(user));
        strategy.burn(user);
        vm.stopPrank();

        assertEq(strategy.balanceOf(user), 0);
        assertEq(strategy.cached(), 0);
        assertEq(strategy.totalSupply(), 0);

        // Reverts due to division by zero: minted = _totalSupply * deposit / cached.
        vm.expectRevert(abi.encodeWithSelector(bytes4(0x4e487b71), uint256(0x12)));
        vm.prank(user2);
        strategy.mint(user);

        vm.warp(maturity + 1 hours);

        // A keeper matures the series first; otherwise debtToBase mutates state inside
        // Strategy view-declared staticcall and reverts before reaching the transfer.
        cauldron.mature(seriesId);

        vm.expectRevert("ERC20: Insufficient balance");
        strategy.endPool();

        // The vault debt is still outstanding and the collateral still locked, forever.
        (uint128 strandedInk, uint128 strandedArt) = cauldron.balances(strategy.vaultId());
        assertGt(strandedArt, 0);
        assertGt(strandedInk, 0);
    }

    // Test to verify direct LP Transfer can't restore the Strategy once all minters burns their tokens. 
    function testPoolLPTransferToStrategy_DontRestoreStrategy() public {
        vm.prank(user);
        strategy.startPool();
        assertGt(strategy.cached(), 0);
        assertEq(strategy.cached(), strategy.balanceOf(user));

        vm.startPrank(user);
        strategy.transfer(address(strategy), strategy.balanceOf(user));
        strategy.burn(user);
        vm.stopPrank();

        assertEq(strategy.balanceOf(user), 0);
        assertEq(strategy.cached(), 0);
        assertEq(strategy.totalSupply(), 0);

        IPool(pool).transfer(address(strategy), AMOUNT);

        assertEq(IPool(pool).balanceOf(address(strategy)), AMOUNT);

        // Reverts due to division by zero: minted = _totalSupply * deposit / cached.
        vm.expectRevert(abi.encodeWithSelector(bytes4(0x4e487b71), uint256(0x12)));
        vm.prank(user2);
        strategy.mint(user2);
    } 
```
</Details>

## Recommendation

Permanently lock a small amount of the initial Strategy shares at an inaccessible address e.g `address(0xdead)` or `address(0)`. This ensures that `totalSupply` and the corresponding portion of `cached` cannot reach zero while the Strategy has an active vault. 

```Solidity
uint256 constant MINIMUM_SUPPLY = 1_000; // Constant variable to hold a minimum supply of strategy shares.

@ line 161
@> function startPool()
        public
    {
    .
    .
    .
    (,, cached) = pool.mint(address(this), true, 0);
    if(_totalSupply == 0) {
        // Revert if deposit is less than the strategy's shares minimum supply. 
        require(cached > MINIMUM_SUPPLY, "Insufficient initial liquidity");
        _mint(address(0xdead), MINIMUM_SUPPLY); // Mint a small amount of strategy shares to the dead address to prevent totalSupply from reaching zero. 
        _mint(msg.sender, cached - MINIMUM_SUPPLY); // Mint the remaining strategy shares to the pool starter. 
    }
```

# Low 

## [L-01] Tokens pre-transferred to the FYToken contract can be consumed by another user's redemption or repayment

## Summary
The FYToken contract burns tokens it holds before touching the user's wallet.
A user who pre-transfers fyToken to the contract (the documented way to save
the cost of approve or permit) can have those tokens used up by someone else's
redeem or burn first.

## Root Cause
`FYToken._burn()` spends `_balanceOf[address(this)]` first, no matter who sent
those tokens. The contract treats its whole held balance as one shared pool.

## Impact
`Low` — Only users who choose the optional pre-transfer shortcut are exposed,
and every operation has a single-transaction alternative that is not
front-runnable: `redeem()` burns straight from the caller's own wallet when
the held balance runs short, and debt repayment can use an approval instead
of a pre-transfer. So this is a real mechanic with a cheap escape route —
the loss lands only on users who leave a gap between transferring and calling. 