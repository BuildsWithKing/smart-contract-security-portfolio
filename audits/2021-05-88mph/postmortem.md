# My Summary and Progress So Far

**What I understood:** This protocol allows users to deposit stablecoins for a certain period and earn a fixed interest rate. Users can withdraw their capital at any time, but if they withdraw before maturity, they pay an early-withdrawal fee. These fees accumulate in the `totalFeeOwed` state variable and are transferred to the fee beneficiary.

Funders also earn dividends. I believe funding helps prevent the protocol from becoming unable to meet its obligations to depositors when `totalDeposit`, including `totalInterestOwed`, becomes greater than the deposits and earnings received from the money market. I would describe these funds as helping the protocol avoid insolvency.

**What confused me:** Honestly, the mathematics. I found it difficult to understand what the developers were doing at different points in the protocol, and I sometimes concluded that the calculations were correct without fully understanding them.

## Bugs and Hypotheses I Tested

1. My first hypothesis came from the `deposit` function. I questioned whether `feeAmount` could ever become greater than `interestAmount`. I found that `interestAmount` was calculated first and `feeAmount` was derived from it. After reading the fee model, I also found a maximum interest fee, so I concluded that this was a false positive.

2. My second hypothesis was that `EMAOracle::updateAndQuery` could revert when the money-market income index decreased. I noted it during my review and later returned to validate it.

3. My third hypothesis became my first independently reproduced issue. I traced `rolloverDeposit` and found that users who roll over without withdrawing their old vested rewards can lose those accumulated rewards.

4. I asked many questions and invalidated several false positives during this review. I also learned the difference between issues in protocol contracts, deployment scripts, and test files.

## What I Would Do Differently In My Next Audit

- I would spend more time reading the protocol's README and understanding what the protocol does before diving deeply into the code. I spent a lot of time trying to understand the codebase after I had already started reading it.

- I struggled with the mathematics, and I am still learning how to improve in this area.

- I sometimes got lost by following one external contract after another. Next time, I will stay focused on the main flow and only inspect external contracts when they affect the hypothesis I am testing.

- I am still learning whether reading smaller contracts first helps me understand the main contract. The size of the main contract initially felt overwhelming because I did not yet understand the protocol well.

A lot is still on my mind, but I am grateful for how far I have come and what I learned from this review.

## Missed Patterns From The Official Report

### [M-01] Incompatibility with deflationary or fee-on-transfer tokens

I missed this because I assumed that since the protocol works with stablecoins, `amount transferred == amount received`.

The better audit pattern is to verify every ERC20 transfer by checking whether the protocol records the requested amount or the actual balance change.

**What I should have checked:**

- Does `deposit()` record `depositAmount` before confirming the actual amount received?
- Does the money market receive the same amount that `DInterest` thinks it deposited?
- Are supported stablecoins strictly trusted and non-deflationary, or can arbitrary ERC20-like stablecoins be used?

**Pattern learned:** Never trust the token label. Even if the protocol says "stablecoin," verify whether its accounting uses the requested transfer amount or the actual amount received.

**What I will check earlier next time:** I will verify whether the protocol's accounting uses the actual amount received.

### [M-02] Not checking MPH ownership in `distributeFundingRewards` can cause critical functions to revert

I missed that `distributeFundingRewards()` calls `mph.ownerMint()` without first checking whether `MPHMinter` is still the owner of the MPH token. Other minting functions safely return when `mph.owner() != address(this)`, but this function does not, so user-facing `DInterest` flows can revert.

**What I should have checked:**

- I should have stayed with one function and traced it from beginning to end while asking who was authorized to call it.
- Since this function is called by user-facing functions, can it revert and deny users access if the calling contract's ownership has not been checked?

**Pattern learned:** Verify who is allowed to call each function. If a user-facing flow calls a reward or minting function, verify that a failure in the reward logic cannot revert the core user flow unless that behavior is intentional.

**What I will check earlier next time:** I will verify whether ownership checks safely return in functions that are directly or indirectly called by user-facing functions.

### [L-01] Use OpenZeppelin ECDSA instead of raw `ecrecover`

I missed this because I did not review the `Sponsorable.sol` contract.

**What I should have checked:**

- How does sponsorship work?
- How can a user authorize another user to perform on-chain transactions on their behalf?
- Where is the recovered address used?
- Is `address(0)` checked?
- Is a nonce used?
- Is the chain ID included?
- Is a deadline checked?
- Is replay possible?
- Is the signed digest domain-separated?
- What happens if the signature is malformed?

**Pattern learned:** Raw `ecrecover` is not equivalent to using an audited ECDSA recovery library.

**What I will check earlier next time:** I will check whether the protocol allows a user to sponsor on-chain transactions on behalf of another user. More generally, I will ask how the protocol uses signatures and whether it uses a well-known, audited library.

### [L-02] Anyone can withdraw a vested amount on behalf of someone else

I did not review the `Vesting.sol` contract during my initial pass. After reading the finding title, I went to the contract and reviewed it, but I still did not immediately see what was wrong.

**What I should have checked:** I should have carefully asked what happens when the `account` or `receiver` is a smart contract that has no way to transfer the tokens out.

**Pattern learned:** Smart contracts are not built only for EOAs. Smart contract wallets and integrations must also be considered, so I should ask what happens when the `from` or `to` address is a contract.

**What I will check earlier next time:** If a function lets anyone trigger an action for another address, I will check whether the receiving address loses control over timing or follow-up logic.

### [L-03] Extra precautions in `updateAndQuery`

**Status:** I had already found and traced this during my review.

**Pattern reinforced:** External indexes and oracles can move unexpectedly; check monotonicity assumptions before subtraction.

### [L-04] Add an explicit error in `_depositRecordData`

I noticed this during my review, but I did not find an impact or a realistic situation where `feeAmount` could become greater than `interestAmount`, because the interest fee has a maximum value.

**Pattern reinforced:** Keep issues like this as informational when the impact is low.

### [L-05] `payInterestToFunders` does not have a reentrancy modifier

I also noticed that `payInterestToFunders` lacks the `nonReentrant` modifier, but I found no broken invariant or user funds at risk, so I did not report it as a vulnerability.

**Pattern reinforced:** Keep issues like this as informational when the impact is low.
