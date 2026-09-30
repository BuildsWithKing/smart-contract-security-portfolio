# Sherlock v1 Audit

## Protocol Summary
Sherlock is a protocol on the Ethereum blockchain that aims to protect users' funds across different protocols. It connects decentralized security researchers, known as Watsons, who review protocols added to the platform. Stakers can stake different ERC20 tokens to earn a share of the premiums paid by protocols. If an exploit occurs, Sherlock transfers a `payout` from the staked assets to the affected protocol so it can compensate its users.

## Assets
- ERC20 tokens: premium tokens
- ERC20 tokens: staked tokens
- SherX tokens: redeemable for underlying staked assets

## Actors
- Protocol Agents
- DAO
- Stakers

## Findings I Missed

### [[H-01] Single under-funded protocol can break paying off debt](https://github.com/code-423n4/2021-07-sherlock-findings/issues/119)

I missed this because I did not consider what happens when a protocol is underfunded and its debt exceeds its balance, causing the `LibPool::payOffDebtAll` loop to revert.

**What I should have checked:**
- I should have asked what happens if a protocol is underfunded or its debt exceeds its balance.
- I should have checked whether a revert in this function can block users from completing user-facing operations.

**Pattern learned:** Reason through different protocol states, such as fully funded, underfunded, and overfunded, and check whether a revert can prevent users from completing core actions.

**What I will check earlier next time:** I will check whether the protocol loops through all registered protocols and whether any can be underfunded or owe more than their balance.


### [[H-02] [Bug] A critical bug in `bps` function](https://github.com/code-423n4/2021-07-sherlock-findings/issues/90)

I missed this because I did not understand the `bps` function or trace what it actually returned.

**What I should have checked:**
- I should have checked whether a malicious user could inject extra values at the end of `calldata` and fake return values.
- I should have checked whether the function reads from storage or uses a helper that consistently returns the expected value.

**Pattern learned:** Do not assume a helper reads the same value as its explicit function parameter. Trace how it reads `calldata` and check whether trailing values can change which token the calculations use.

**What I will check earlier next time:** I will check whether a malicious user can inject extra values at the end of `calldata` and fake return values.

### [[M-02] `_doSherX` optimistically assumes premiums will be paid](https://github.com/code-423n4/2021-07-sherlock-findings/issues/107)

I missed this because I did not consider what happens if a protocol fails to pay its accrued debt on time and `payout` is called. This could inflate users' balances through `LibSherX.calcUnderlying(totalSherX);`.

**What I should have checked:**
- Could the amount users can claim be inflated by an assumption made by the developer?
- Have I traced and understood assumptions made to save gas?

**Pattern learned:** Conditional statements are a good place to ask questions and trace assumptions and function calls.

**What I will check earlier next time:** I will trace developers' assumptions and test whether users could claim more than expected under different scenarios.

### [[M-03] Reputation risks with `updateSolution`](https://github.com/code-423n4/2021-07-sherlock-findings/issues/4)

I missed this because I trusted the DAO and did not consider the harm an immediate protocol upgrade could cause to the protocol and its users' funds.

**What I should have checked:**
- Can the DAO upgrade the protocol without users' consent?
- Does the protocol have a timelock or delay that gives users who oppose an upgrade time to withdraw their funds?

**Pattern learned:** In every upgradeable codebase, ask whether the DAO can upgrade the protocol without users' consent.

**What I will check earlier next time:** In upgradeable contracts, I will check how the DAO or another authorized party upgrades the code and whether a timelock gives users time to withdraw their funds.

*Never blindly trust DAOs or admins in situations like this: users' funds could be mismanaged or moved without their consent.*

### [[M-04] Yield distribution after large payout seems unfair](https://github.com/code-423n4/2021-07-sherlock-findings/issues/50)

I focused on whether `payout` and `doYield` could unfairly reduce `unallocatedSherX`. The sponsor explained that `sWeight` is also reduced, so the remaining SherX is distributed fairly. The confirmed issue was different: if `payout()` is called with `_unallocatedSherX > 0` after a user has called `harvest()`, that user is blocked from calling `harvest()` again and transferring their lock token.

**What I should have checked:**
- How do `payout`, `harvest`, and lock-token transfers interact when `_unallocatedSherX > 0`?
- Can calling `harvest()` before `payout()` block a later `harvest()` call or lock-token transfer?
- Does the reduction in `sWeight` preserve fair reward distribution after a payout?

**Pattern learned:** Trace state changes across function order, and distinguish a suspected accounting unfairness from the behavior the sponsor confirms.

**What I will check earlier next time:** I will test important call sequences and check whether a payout can block later claims or transfers, then verify the final impact against the protocol's accounting.


### [[L-02] `withdraw` returns the final amount withdrawn](https://github.com/code-423n4/2021-07-sherlock-findings/issues/78)

I missed this because I had not read `AaveV2.sol` in the strategies directory.

**What I should have checked:**
- Does the strategy validate the return value from Aave's withdraw function?

**Pattern learned:** Read functions to understand what they return, and check whether callers validate returned values instead of ignoring them.

**What I will check earlier next time:** If a function returns a value, I will check whether every caller validates it.

### [[L-03] A series of divisions](https://github.com/code-423n4/2021-07-sherlock-findings/issues/24)

I missed this because I did not notice the sequential divisions in `payout`, which can cause precision loss. The report also noted a possible division by zero if `totalSupply` is zero.

**What I should have checked:**
- I should have checked the precision loss from sequential divisions and whether any intermediate denominator could be zero.

**Pattern learned:** Check both operation order and every intermediate denominator; multiplying before dividing can reduce precision loss when the equivalent formula and zero-denominator cases are handled correctly.

**What I will check earlier next time:** I will trace units, rounding, and zero-denominator cases through multi-step calculations.

### [[L-04] ERC20 non-standard names](https://github.com/code-423n4/2021-07-sherlock-findings/issues/117)

I missed this because I did not know that non-standard function names could be reported as findings. While reviewing the codebase, I got stuck on `decreaseApproval` trying to understand what it did, but I did not check it against the commonly used `decreaseAllowance` name.

**What I should have checked:**
- I should have checked whether `increaseApproval` and `decreaseApproval` matched the commonly used `increaseAllowance` and `decreaseAllowance` names, and whether those names are standard functions or library conventions.

**Pattern learned:** Distinguish functions required by a standard from commonly used extension names, and investigate confusing names instead of assuming they are correct.

**What I will check earlier next time:** I will compare public APIs with the relevant standard and common library conventions, and verify which functions each one actually requires.

### [[L-05] User’s `calcUnderlyingInStoredUSD` value is underestimated](https://github.com/code-423n4/2021-07-sherlock-findings/issues/144)

I missed this because I did not compare `calcUnderlyingInStoredUSD()` with `calcUnderlying()`. The former uses the user's stored SherX balance and can omit SherX that is unallocated to that user.

**What I should have checked:**
- Does `calcUnderlyingInStoredUSD()` account for unallocated SherX in the same way as `calcUnderlying()`?

**Pattern learned:** Similar view functions can return different values if one includes unallocated balances and another uses only stored user balances.

**What I will check earlier next time:** I will compare related view functions and trace exactly which stored and unallocated balances each one includes.

### [[L-06] `PoolStrategy.sol`: Consider minimizing trust with implemented strategies](https://github.com/code-423n4/2021-07-sherlock-findings/issues/44)

I missed this because I did not pay enough attention to `PoolStrategy.sol`. I did not notice that the contract trusted the strategy without verifying its return value or checking whether the contract's balance increased.

**What I should have checked:**
- I should have checked how the protocol deposits funds into and withdraws funds from strategies, and whether it verifies the resulting balance changes.

**Pattern learned:** Protocols should not trust strategies without verifying returned values and checking whether the protocol's balance changed as expected after a withdrawal.

**What I will check earlier next time:** I will study the strategies a protocol uses and check how it deposits funds into them and withdraws funds from them.

### [[L-07] Unbounded iteration over all premium tokens](https://github.com/code-423n4/2021-07-sherlock-findings/issues/102)

### [[L-08] Unbounded iteration over all staking tokens](https://github.com/code-423n4/2021-07-sherlock-findings/issues/103)

### [[L-09] Unbounded iteration over all protocols](https://github.com/code-423n4/2021-07-sherlock-findings/issues/104)

I missed these because I did not consider that the number of premium tokens, staking tokens, or protocols could grow until the loops became too expensive and reverted, preventing `Gov` from performing core operations.

**What I should have checked:**
I should have checked whether every loop is bounded. Any loop over a dynamic array deserves scrutiny for unbounded growth.

**Pattern learned:** An unbounded loop can grow until its gas cost exceeds the block limit and reverts a core operation.

**What I will check earlier next time:** I will check whether every loop is bounded.

### [[L-10] Missing verification on `tokenInit`’s lock](https://github.com/code-423n4/2021-07-sherlock-findings/issues/105)

I missed this because I thought the existing check
```solidity
if (address(_token) != address(this)) {
require(_lock.underlying() == _token, 'UNDERLYING');
}
```
was sufficient and did not ask whether the lock's underlying token was also checked when `_token` was SherX.

**What I should have checked:**
- I should have asked what happens when the token is SherX.
- Can a lock contract use a different underlying token and still pass the existing checks?

**Pattern learned:** Treat every special-case check as a hypothesis and trace how it could be bypassed.

**What I will check earlier next time:** I will not assume a special-case check is sufficient. I will ask what could break it or allow it to be bypassed.


### [[L-11] `_doSherX` does not return correct precision and it’s confusing](https://github.com/code-423n4/2021-07-sherlock-findings/issues/108)

**Pattern learned:** `_doSherX` returns `sherUsd` inflated by `1e18`; its caller in `payout` compensates by dividing by `1e18`. Return documented units where possible, and account for compensating conversions at call sites.

### [[L-12] Anyone can unstake on behalf of someone](https://github.com/code-423n4/2021-07-sherlock-findings/issues/114)

**Pattern learned:** A third party can trigger `unstakeWindowExpiry` for another user. Even when funds go to the correct address, triggering an action can disrupt a contract wallet's follow-up logic or leave funds locked in that wallet.

### [[L-13] Sanitize `_weights` in `setWeights` on every use](https://github.com/code-423n4/2021-07-sherlock-findings/issues/115)

**Pattern learned:** Unsafe casts can truncate a `uint` value and cause stored state to differ from the intended value.


### [[L-14] `initializeSherXERC20` can be called more than once](https://github.com/code-423n4/2021-07-sherlock-findings/issues/116)

**Pattern learned:** If a function is intended to initialize contract state only once, prevent later calls from overwriting values such as the ERC-20 name and symbol.

### [[L-15] ERC20 can accidentally burn tokens](https://github.com/code-423n4/2021-07-sherlock-findings/issues/118)

**Pattern learned:** ERC-20 `transfer` and `transferFrom` should not allow transfers to the zero address unless burning is an explicit, supported operation.

### [[L-16] Extra checks for `setUnstakeWindow` and `setCooldown`](https://github.com/code-423n4/2021-07-sherlock-findings/issues/18)

**Pattern learned:** Rejecting zero unstake windows or cooldowns can prevent users from staking and unstaking within one flash-loan transaction.

### [[L-17] delete `ps.stakeBalance`](https://github.com/code-423n4/2021-07-sherlock-findings/issues/20)

**Pattern learned:** Reset state consistently, including when no transfer is required.

### [[L-18] Prevent division by zero](https://github.com/code-423n4/2021-07-sherlock-findings/issues/22)

**Pattern learned:** Test each suspected zero denominator against the surrounding guards and state. The sponsor explained that several reported cases cannot reach zero; however, `stakeBalance` can be depleted by `payout()`, leaving a possible zero denominator in `stake()`.


### [[L-19] Unbounded loop in `getInitialUnstakeEntry`](https://github.com/code-423n4/2021-07-sherlock-findings/issues/26)

**Pattern learned:** A per-user array can still grow without bound, but this report noted that `getInitialUnstakeEntry` is unused in the contracts and the impact is limited to the caller's own entries.

### [[L-20] prevent burn in `_transfer`](https://github.com/code-423n4/2021-07-sherlock-findings/issues/29)

**Pattern learned:** Treat transfers to the zero address as burns, and support them only through a function that updates the total supply appropriately.

### [[L-21] AaveV2 approves lending pool in the constructor](https://github.com/code-423n4/2021-07-sherlock-findings/issues/65)

**Pattern learned:** AaveV2 fetches its lending pool address through `getLp()`, and that address can change. An unlimited approval to an old implementation will not authorize the new one; ensure the active pool has the required allowance.

### [[L-22] Inclusive checks](https://github.com/code-423n4/2021-07-sherlock-findings/issues/68)

**Pattern learned:** Check boundary conditions carefully and verify whether comparisons should be inclusive.

### [[L-23] Group related data into separate structs](https://github.com/code-423n4/2021-07-sherlock-findings/issues/69)

**Pattern learned:** Grouping related data in structs can make updates and cleanup less error-prone.

### [[L-24] Re-entrancy mitigation](https://github.com/code-423n4/2021-07-sherlock-findings/issues/70)

**Pattern learned:** Contracts that interact with external tokens, strategies, or users should assess reentrancy risks and apply appropriate protections, such as a `nonReentrant` modifier.

### [[L-25] `getInitialUnstakeEntry` when `unstakeEntries` is empty](https://github.com/code-423n4/2021-07-sherlock-findings/issues/92)

**Pattern learned:** Functions that return an index into an array should handle empty arrays explicitly to avoid ambiguous results.

### [[L-26] Loops may exceed gas limit](https://github.com/code-423n4/2021-07-sherlock-findings/issues/93)

**Pattern learned:** Loops over dynamic arrays can exceed the block gas limit and revert. Bound array growth or provide a way to remove processed entries.

### [[L-27] `SafeMath` library is not always used in `PoolBase`](https://github.com/code-423n4/2021-07-sherlock-findings/issues/133)

**Pattern learned:** Use SafeMath consistently in contracts that perform arithmetic to help prevent underflows and overflows.

### [[L-28] Missing non-zero address checks](https://github.com/code-423n4/2021-07-sherlock-findings/issues/135)

**Pattern learned:** Add zero-address checks to sensitive functions where a zero address could cause lost access or invalid state.

## [[L-29] Possible divide-by-zero error in `PoolBase`](https://github.com/code-423n4/2021-07-sherlock-findings/issues/136)

**Pattern learned:** Check the combined denominator in `getSherXPerBlock`; if both the lock-token supply and `_lock` are zero, return safely instead of dividing by zero.

## [[L-30] Inconsistent block number comparison when deciding an unstaking entry is active](https://github.com/code-423n4/2021-07-sherlock-findings/issues/139)

**Pattern learned:** Keep block-number comparisons consistent across functions that determine whether an unstaking entry is active.

## [[L-31] Tokens cannot be reinitialized with new lock tokens](https://github.com/code-423n4/2021-07-sherlock-findings/issues/141)

**Pattern learned:** Consider how tokens can be replaced or reinitialized, while accounting for the effect on existing lock-token holders.
