# FuzePreSale Smart Contract: User Manual

**Version:** 1.1 (Refactored)
**Date:** July 20, 2025

## Table of Contents

1.  [Introduction](https://www.google.com/search?q=%231-introduction)
2.  [For Project Owners (Admin Guide)](https://www.google.com/search?q=%232-for-project-owners-admin-guide)
      * [2.1 Deployment Parameters](https://www.google.com/search?q=%2321-deployment-parameters)
      * [2.2 Sale Lifecycle Management](https://www.google.com/search?q=%2322-sale-lifecycle-management)
3.  [For Users (Investor Guide)](https://www.google.com/search?q=%233-for-users-investor-guide)
      * [3.1 How to Participate](https://www.google.com/search?q=%2331-how-to-participate)
      * [3.2 Buying Tokens](https://www.google.com/search?q=%2332-buying-tokens)
      * [3.3 Understanding Your Vesting Schedule](https://www.google.com/search?q=%2333-understanding-your-vesting-schedule)
      * [3.4 Checking and Claiming Your Tokens](https://www.google.com/search?q=%2334-checking-and-claiming-your-tokens)

-----

## 1\. Introduction

The `FuzePreSale` smart contract is designed to manage a token presale with a built-in vesting schedule for each purchase. This manual provides instructions for both the project administrators who will manage the sale and the users who will invest in it.

The contract facilitates the sale of a primary token (e.g., FUZE) in exchange for a stablecoin (e.g., USDT, USDC).

-----

## 2\. For Project Owners (Admin Guide)

This section details the administrative functions required to deploy and manage the presale. All administrative functions can only be called by the address designated as the `PROJECTOWNER` during deployment.

### 2.1 Deployment Parameters

When deploying the contract, you must provide the following parameters to the constructor. It is critical that these values are correct, as most are **immutable** (cannot be changed after deployment).

| Parameter | Type | Description | Value |
| :--- | :--- | :--- | :--- |
| `_tokenAddress` | `address` | The address of the ERC20 token being sold (FUZE). | `0x217708dd4505D11429c54A77771ef060Ac917E36` |
| `_stableCoinAddress` | `address` | The address of the ERC20 stablecoin used for payment. | `0xdac17f958d2ee523a2206206994597c13d831ec7` |
| `_stableCoinDecimals`| `uint8` | The number of decimals of the stablecoin. | `6` |
| `_rate` | `uint256` | The number of FUZE token *wei* (smallest unit) per **whole** stablecoin unit. To calculate, use: `(Tokens Per Stablecoin) * (10 ** FUZE_DECIMALS)`. | `5000 * (10**18)` |
| `_maxUserBuyingLimit`| `uint256` | The maximum amount of stablecoin a single user can spend, in **whole units**. Set to `0` for no limit. | `100000`|
| `_projectOwner` | `address` | The address that will have administrative control over the sale. | `0xa115cd8B80fD28Ee00B7248E0129DBA5E761Dfc9`|
| `_tgeUnlockPercent` | `uint256` | The percentage of tokens unlocked immediately at purchase (TGE). | `10`|
| `_cliffPeriod` | `uint256` | The duration in **days** after purchase before linear vesting begins. | `10` |
| `_vestingPeriod` | `uint256` | The duration in **days** for linear vesting *after* the cliff ends. | `2000` |

### 2.2 Sale Lifecycle Management

#### Step 1: Fund the Contract

Before starting the sale, you must transfer the total amount of tokens to be sold **to the `PROJECTOWNER` address**. The `startSale` function will then pull these tokens into the contract.

#### Step 2: Start the Sale

Call the `startSale` function to begin the presale.

  * **Function:** `startSale(uint256 _tokenAmount, uint256 _periodSaleInDays)`
  * **Action:** You must first **approve** the `FuzePreSale` contract address to spend your FUZE tokens. Then, call this function. It transfers the tokens from your wallet to the contract, sets the sale duration, and marks the sale as active.
  * **Parameters:**
      * `_tokenAmount`: The total amount of FUZE tokens available for this sale (in wei, i.e., including decimals).
      * `_periodSaleInDays`: The number of days the sale will be active.

#### Step 3: End the Sale (Optional)

The sale ends automatically when the `endDate` is reached. If you need to end it prematurely, you can call `endSale`.

  * **Function:** `endSale()`
  * **Action:** Immediately stops the sale, preventing further purchases.

#### Step 4: Withdraw Raised Funds

At any time during or after the sale, you can withdraw the stablecoins raised.

  * **Function:** `withdrawStableCoin(address _receiver)`
  * **Action:** Transfers the entire stablecoin balance of the contract to the specified receiver address.

#### Step 5: Withdraw Unsold Tokens

After the sale has concluded (either by time or by calling `endSale`), you can retrieve any tokens that were not sold.

  * **Function:** `withdrawUnsoldTokens()`
  * **Action:** Calculates the unsold token amount and transfers it back to the `PROJECTOWNER` address.

-----

## 3\. For Users (Investor Guide)

This section explains how to participate in the presale, buy tokens, and claim them according to the vesting schedule.

### 3.1 How to Participate

1.  **Wallet:** You need a web3 wallet compatible with the Ethereum network (e.g., MetaMask, Trust Wallet).
2.  **Stablecoins:** You must have the required stablecoin (e.g., USDT) in your wallet to make a purchase.
3.  **Gas:** You will need the native currency of the blockchain (e.g., ETH) to pay for transaction fees (gas).

### 3.2 Buying Tokens

To buy FUZE tokens, you must first **approve** the `FuzePreSale` contract to spend your stablecoins.

1.  **Approve:** On a block explorer like Etherscan (or through your project's UI), call the `approve` function on the **stablecoin's contract**.
      * `spender`: The `FuzePreSale` contract address.
      * `amount`: The amount of stablecoin you wish to spend (in its smallest unit).
2.  **Buy:** Call the `buyToken` function on the **`FuzePreSale` contract**.
      * **Function:** `buyToken(uint256 _stableAmount)`
      * **Parameter:**
          * `_stableAmount`: The amount of stablecoin you are spending (in its smallest unit). For example, to spend 100 USDT (which has 6 decimals), you would enter `100000000`.

Each time you call `buyToken`, you create a new **purchase order** with its own unique vesting schedule. Your first purchase is order \#1, your second is order \#2, and so on.

### 3.3 Understanding Your Vesting Schedule

For every purchase you make, your tokens are subject to the following schedule:

1.  **TGE (Token Generation Event):** A percentage of your purchased tokens is unlocked and available to claim immediately.
2.  **Cliff:** A waiting period (e.g., 90 days) begins at the time of your purchase. During this time, no *additional* tokens unlock.
3.  **Linear Vesting:** After the cliff period ends, the remaining tokens begin to unlock gradually, block by block, over the vesting period (e.g., 365 days).

### 3.4 Checking and Claiming Your Tokens

You can check your claimable balance and withdraw your unlocked tokens at any time.

#### Checking Your Balance

  * `checkTotalClaimableAmount(your_address)`: Returns the **total** number of tokens you can claim across ALL your purchase orders combined.
  * `calculateClaimableAmount(your_address, order_index)`: Returns the claimable amount for a **single** purchase order.
  * `getOrderInfo(your_address, order_index)`: Shows you details about a specific purchase, including how much you bought and how much you've already claimed.

#### Claiming Your Tokens

You have two options for claiming:

1.  **Claim a Single Order:**

      * **Function:** `claimToken(uint256 _orderIndex)`
      * **Use Case:** Ideal for claiming a specific purchase.
      * **Example:** `claimToken(1)` to claim from your first purchase.

2.  **Claim Multiple Orders (Recommended for Gas Savings):**

      * **Function:** `claimMultipleOrders(uint256[] calldata _orderIndexes)`
      * **Use Case:** The most efficient way to claim from several orders at once.
      * **Example:** To claim from your first, third, and fourth purchases, you would call `claimMultipleOrders([1, 3, 4])`.
