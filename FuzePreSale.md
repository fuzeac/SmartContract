# **FuzePreSale.sol Smart Contract Analysis**

## **1\. Overview**

The FuzePreSale smart contract is designed to manage a token presale for a token named "FUZE". It is a feature-rich contract that facilitates the sale of tokens in exchange for a stablecoin (specifically configured for USDT) and includes a vesting schedule for purchased tokens.

### **Key Features:**

* **Role-Based Access Control:** Uses OpenZeppelin's Ownable and AccessControl to define a PROJECTOWNER role with administrative privileges.  
* **Pausable:** The contract can be paused by the owner, halting key functions like buyToken.  
* **Vesting Schedule:** Each purchase is subject to a vesting schedule defined by three parameters:  
  1. **TGE Unlock:** A percentage of tokens are immediately claimable upon purchase.  
  2. **Cliff Period:** A duration during which no additional tokens can be claimed.  
  3. **Linear Vesting:** After the cliff, the remaining tokens are released linearly over a specified period.  
* **Purchase Logic:** Users can buy tokens with a stablecoin. The contract tracks individual user purchases and total funds raised.  
* **Administrative Functions:** The project owner can start/end the sale, withdraw the raised stablecoins, and reclaim any unsold tokens after the sale concludes.

## **2\. Security Analysis**

The contract incorporates several standard security best practices by using OpenZeppelin's battle-tested libraries. However, it contains a **critical flaw** in its core logic that would lead to catastrophic failure if deployed as-is.

### **❗ Critical Vulnerability: Incorrect Token Calculation**

The most severe issue lies within the buyToken function. The formula used to calculate the number of tokens a user receives for their stablecoin payment is fundamentally incorrect.

**The Flawed Code:**

uint256 constant TOKEN\_DECIMALS \= 1e18;  
// ...  
uint256 tokenAmount \= (rate \* \_stableAmount) / TOKEN\_DECIMALS;

**Analysis:**

* \_stableAmount is the amount of stablecoin paid, expressed in its smallest unit. For USDT, which has **6 decimals**, 1 USDT is represented as 1,000,000.  
* TOKEN\_DECIMALS is hardcoded to 1e18, representing the 18 decimals of the FUZE token.  
* The formula incorrectly divides by the FUZE token's decimals (1e18) instead of the stablecoin's decimals (1e6).

Impact:  
This error means that a user paying 1 USDT (1,000,000 smallest units) would receive (rate \* 1,000,000) / 1,000,000,000,000,000,000 tokens. This result is one trillion times smaller than the intended amount. This would lead to:

* **Massive financial loss for every investor.**  
* **Complete failure of the presale.**  
* **Irreparable damage to the project's reputation.**

Recommendation: Immediate Fix Required  
The formula must be corrected to scale the calculation using the stablecoin's decimals.  
**Corrected Implementation:**

// Define a constant for stablecoin decimals for clarity and correctness  
uint256 constant STABLECOIN\_DECIMALS \= 1e6; // For USDT

// Inside the buyToken function  
uint256 tokenAmount \= (\_stableAmount \* rate) / STABLECOIN\_DECIMALS;

### **⚠️ Medium-Severity Issues**

#### **Gas Cost of claimAll**

The claimAll function uses a for loop to iterate through all of a user's past purchase orders.

for (uint256 i \= 1; i \<= userOrderCount; i++) {  
    // ... logic to calculate and aggregate claimable amounts  
}

If a user makes a large number of small purchases, the gas required to execute this loop could eventually exceed the block gas limit. This would make the claimAll function permanently unusable for that user, forcing them to claim each order individually via claimToken, which is inconvenient and costly.

### **✅ Strengths and Best Practices**

Despite the critical flaw, the contract demonstrates a good understanding of common security patterns.

* **Standard Library Usage:** Correctly uses Ownable, AccessControl, ReentrancyGuard, Pausable, and SafeERC20 from OpenZeppelin.  
* **Reentrancy Protection:** The claimToken and claimAll functions are properly secured with the nonReentrant modifier, preventing reentrancy attacks during token transfers.  
* **Clear Vesting Logic:** The calculateClaimableAmount function is logically sound and correctly implements the intended TGE, cliff, and linear vesting mechanism.  
* **Robust Event Logging:** The contract emits events for all significant state changes, which is crucial for transparency and integration with off-chain services and user interfaces.  
* **Input Validation:** Most functions include require statements to validate inputs and state conditions (e.g., checking for active sale period, non-zero amounts).

## **3\. Final Conclusion and Recommendations**

The FuzePreSale contract is conceptually well-designed but is critically flawed in its current state due to the incorrect token calculation logic.

**Before any deployment, it is imperative to:**

1. **Fix the Token Calculation:** Correct the formula in the buyToken function as described above. This is a non-negotiable, critical fix.  
2. **Consider the Gas Limit of claimAll:** While not a critical vulnerability, the team should be aware of the potential for high gas costs. For a presale, this might be an acceptable risk, but an alternative design could involve users claiming for multiple orders in batches.  
3. **Add More Comments:** Specifically, the rate variable should be explicitly documented to clarify what it represents (e.g., "The number of FUZE wei received for 1 whole stablecoin unit").

The contract should undergo a thorough internal review and ideally a professional audit after these changes are implemented.
