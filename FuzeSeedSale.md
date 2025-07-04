### **User Story**

As a Project Owner, I want a secure smart contract to manage the FUZE token seed round, including vesting, whitelisting, and manual staking rewards, so that I can conduct a fair and transparent sale for early investors.

***

### **Acceptance Criteria**

#### **Investor (Buyer)**

* **Given** an investor is whitelisted and the sale is active
    **When** they call the `buyToken` function with a valid stablecoin amount
    **Then** their purchase is recorded, and the stablecoins are transferred to the contract.

* **Given** an investor is not whitelisted
    **When** they attempt to call `buyToken`
    **Then** the transaction must fail with a "User not whitelisted" error.

* **Given** an investor attempts to buy tokens for an amount exceeding their `maxUserBuyingLimit`
    **When** they call `buyToken`
    **Then** the transaction must fail with an "Exceeds max buy limit" error.

* **Given** an investor has purchased tokens
    **When** they call `claimToken` immediately
    **Then** they should successfully receive exactly 3% of their purchased tokens (TGE unlock).

* **Given** an investor has purchased tokens
    **When** they attempt to `claimToken` during the 40-day cliff period (after the TGE claim)
    **Then** the transaction should fail or result in a claim amount of zero.

* **Given** an investor's 40-day cliff period has passed
    **When** they call `claimToken`
    **Then** they should successfully receive all vested tokens available to date (including the linear portion).

* **Given** an investor's 40-day cliff period has passed and their staking rewards have been added
    **When** they call `claimRewardStaking`
    **Then** they should successfully receive all their available staking rewards.

* **Given** an investor attempts to `claimRewardStaking` before their 40-day cliff period ends
    **When** they call the function
    **Then** the transaction must fail with a "Cliff period has not ended" error.

#### **Project Owner / Admin**

* **Given** the contract is ready for deployment
    **When** it is deployed with the correct constructor arguments (FUZE address, stablecoin address, rate, etc.)
    **Then** the contract address is created and the `PROJECTOWNER_ROLE` is assigned correctly.

* **Given** sufficient FUZE tokens have been transferred to the contract
    **When** the Project Owner calls `startSale` with a valid token amount and duration
    **Then** the sale becomes active, and the `startDate` and `endDate` are set.

* **Given** the sale is active
    **When** the Project Owner calls `withdrawStableCoin`
    **Then** all collected stablecoins in the contract are transferred to the owner's wallet.

* **Given** the sale has ended
    **When** the Project Owner calls `withdrawUnsoldTokens`
    **Then** all remaining (unsold) FUZE tokens are transferred to the owner's wallet.

#### **Whitelister Role**

* **Given** an address has the `WHITELISTER_ROLE`
    **When** they call `updateWhitelist` with a list of investor addresses and a `true` status
    **Then** those addresses are successfully marked as whitelisted.

* **Given** an address does not have the `WHITELISTER_ROLE`
    **When** they attempt to call `updateWhitelist`
    **Then** the transaction must fail due to a lack of permissions.

#### **Reward Manager Role**

* **Given** an address has the `REWARD_MANAGER_ROLE` and the contract holds sufficient FUZE for rewards
    **When** they call `addStakingReward` for a specific investor with a reward amount
    **Then** the investor's `totalRewardAmount` in their `stakingInfo` is increased.

* **Given** an address does not have the `REWARD_MANAGER_ROLE`
    **When** they attempt to call `addStakingReward`
    **Then** the transaction must fail due to a lack of permissions.
