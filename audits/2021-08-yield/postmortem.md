# Yield v2 Audit

## Protocol Summary

This protocol implements a fixed borrowing and lending rate, where lenders spend underlying assets to buy `fyTokens` then redeem them at maturity and borrowers deposit collaterals, mint/borrow fyTokens, then sell them for underlying. The liquidity providers provide liquidity to earn fees generated from the `YieldSpace` market, where borrowers sell their `fyTokens` and lenders buy `fyTokens`.  


## Missed Findings and Lessons

## [[H-01] `CompositeMultiOracle` returns wrong decimals for prices?](https://github.com/code-423n4/2021-08-yield-findings/issues/26)

I missed this because I did not test chained oracle paths whose source oracles use different precisions. I noticed the `1e18` factors in the `peek` and `get` functions but did not trace how prices were normalized between each oracle call.  

**What I should have checked:**
- I should have identified what `source.decimals` represented and distinguished oracle precision from token decimals.
- I should have simulated a multi-hop oracle path using source oracles with different precisions and checked the final quoted amount.

**Pattern learned:** Token decimals and oracle precision are separate concerns. Every hop in a composite oracle must normalize its input and output consistently.

**What I will check earlier next time:** I will trace the units and precision through every oracle hop and simulate paths with different token decimals and oracle precisions.

## [[H-02] `ERC20Rewards` returns wrong rewards if no tokens initially exist](https://github.com/code-423n4/2021-08-yield-findings/issues/28)

I missed this because I treated zero supply as a harmless edge case and did not trace what happened to `lastUpdated` when `_updateRewardsPerToken()` returned early.

**What I should have checked:**
- I should have checked whether every early-return branch advanced the necessary accounting state.
- I should have traced the transition from zero supply to the first mint and then to the first claim.
- I should have asked who receives rewards accumulated while no one holds the rewarded token.

**Pattern learned:** In time-based accounting, an early return can be dangerous if it leaves the accounting timestamp unchanged. When supply changes from zero to nonzero, the first holder must not receive rewards from before they owned tokens.

**What I will check earlier next time:** I will trace each accounting variable across zero-state transitions, external entry points, and early-return branches.

## [[H-03] `ERC20Rewards` breaks when setting a different token](https://github.com/code-423n4/2021-08-yield-findings/issues/29)

I missed this because i assumed that the developer and the protocol team are aware of the implications of changing the reward token, due to this written note `// If changed in a new rewards program, any unclaimed rewards from the last one will be served in the new token` therefore its a known issue and might not be accepted when submitted as a finding. 

**What I should have checked:**
-  Natspec comments in codebases are assumptions and expected behavior by the developer and i must not always take them as is, i should definitely find scenarios where such assumptions can be broken and submit them as a finding. 

**Pattern learned:** ERC20 tokens have different decimals and changing one reward tokens to another is likely to reward more or less tokens to users and should be checked properly. 

**What I will check earlier next time:** I will create scenarios where different ERC20 tokens with different decimals can be added as rewards and find out which is likely to break the protocol. 


## [[H-04] Rewards accumulated can stay constant and often not increment](https://github.com/code-423n4/2021-08-yield-findings/issues/65)

I missed this because I did not test whether the calculated reward increment could round down to zero while `lastUpdated` still advanced.

**What I should have checked:**
- I should have tested `1e18 * timeSinceLastUpdated * rate / totalSupply` with a small time interval, a low reward rate, and a large token supply.
- I should have checked whether transfers, mints, or burns could repeatedly trigger these small updates.

**Pattern learned:** Never inspect rounding without also checking which state variables advance. Rounding an increment to zero while advancing time can permanently discard value.

**What I will check earlier next time:** I will test whether frequent state-changing operations can repeatedly force zero-value accounting updates while consuming elapsed time.

## [[H-05] Exchange rates from Compound are assumed with 18 decimals](https://github.com/code-423n4/2021-08-yield-findings/issues/38)

I missed this because i didn't spend much time studying the oracle contracts, i only skimmed through them. 

**What I should have checked:**
- I should have checked the decimals the oracle and exchange uses or assumed to use. 

**Pattern learned:** Always review oracles decimals and their source / underlying assets decimals, never assume that they should work as intended. 

**What I will check earlier next time:** I will check and understand the oracle assumptions the protocol made and verify them through the oracle / protocol's documentation. 

## [[M-01] No ERC20 safe* versions called](https://github.com/code-423n4/2021-08-yield-findings/issues/31)

I missed this because i didn't noticed the `claim` function failed to call the `safeTransfer` while transferring the tokens to the claimant.  

**What I should have checked:**
- I should have checked if all tokens transfer calls or uses the `safeTransfer` function and not just `transfer` or `transferFrom`
- I should have verified if the token's transfer return value is properly checked

**Pattern learned:** Most ERC20 tokens behaves weirdly, so their return value must be properly checked and this can be done with `safeTransfer` and `safeTransferFrom`

**What I will check earlier next time:** I will carefully search for all ERC20 transfer and ensure they return value is properly checked using `safeTransfer`


## [[M-02] `TimeLock` cannot schedule the same calls multiple times](https://github.com/code-423n4/2021-08-yield-findings/issues/27)

I missed this because i didn't think of this a scenario where scheduling same call multiple times is neccessary and also i didn't spend much time in this codebase. 

**What I should have checked:**
- I should have checked if the schedule function can schedule same calls multiple times 

**Pattern learned:** Schedule function should be able to schedule same calls multiple times as written in the report *Imagine the delay is set to 30 days, but a contractor needs to be paid every 2 weeks.*

**What I will check earlier next time:** I will check if same calls can be scheduled multiple times. 

## [[M-03] Rewards squatting - setting rewards in different ERC20 tokens opens various economic attacks. ](https://github.com/code-423n4/2021-08-yield-findings/issues/64)

I missed this because i assumed the developer and protocol team are already aware of the risks that comes with changing reward tokens. The natspec comment *// If changed in a new rewards program, any unclaimed rewards from the last one will be served in the new token* made me 
think and believe so. 

**What I should have checked:**
- I should have checked and reason about the risks associated with changing tokens mid claiming. 

**Pattern learned:** A scenario where reward tokens can be changed mid claiming is likely to make users detect if its much more valuable than the old reward token and wait for it to be added before the claiming. 

**What I will check earlier next time:** I will check what users and attakers are likely to do in different scenarios accross every function.  

## [[M-04] Use `safeTransfer` instead of `transfer`](https://github.com/code-423n4/2021-08-yield-findings/issues/36)

This finding is same as `M-01`.

## [[L-01] `updateTime` of get is 0](https://github.com/code-423n4/2021-08-yield-findings/issues/7)

I missed this because I did not trace the initial value of `updateTime` through the composite oracle path.

**What I should have checked:**
- I should have checked the initial timestamp passed into `_get()` and followed the "take the oldest timestamp" comparison across every hop.

**Pattern learned:** An aggregate minimum or maximum calculation must start from a correct identity value. Starting an oldest-timestamp calculation at zero causes the result to remain zero.

**What I will check earlier next time:** I will verify how accumulator and sentinel values are initialized before loops and chained calls.

## [[L-02] Different definition of `beforeMaturity()` and `afterMaturity()` modifier in different file](https://github.com/code-423n4/2021-08-yield-findings/issues/18)

I noticed this difference in `Strategy.sol` and `FYToken.sol`, but I found no serious harm and did not record the resulting behavior as a Low finding.

**What I should have checked:**
- I should have compared the exact maturity boundaries and documented that `Strategy` could mint into an already matured pool.

**Pattern learned:** Compare duplicated modifiers and guards at their exact boundary values. A small inconsistency can permit an unintended operation even when its impact is limited.

**What I will check earlier next time:** I will compare repeated access, time, and state-transition checks across contracts and test their boundary conditions.

## [[L-03] Missing input validation to check that `end` > `start`](https://github.com/code-423n4/2021-08-yield-findings/issues/49)

I found something similar but only noted that there was no `start != end` check. That check would still allow `end < start`; the required invariant is `end > start`.

**What I should have checked:** I should have tested `end == start` and `end < start`, then traced how either case affects the active rewards period.

**Pattern learned:** Validate the complete relationship between related inputs. Checking that two values differ is weaker than checking their required ordering.

**What I will check earlier next time:** For every time range, I will verify `end > start` and trace the behavior of invalid and boundary values.

---
*Note: Finding [L-04] - [L-12] was missed and i have carefully read through and learned from them.*