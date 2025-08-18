// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// --- OpenZeppelin Imports ---
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

// --- Interface Definition ---

/**
 * @title IFuzeVesting
 * @notice Interface for the FuzeVesting contract.
 * @dev Defines the external `allocate` function that the Presale contract will call.
 */
interface IFuzeVesting {
    function allocate(address _user, uint256 _amount) external;
}

// --- Vesting Contract (No changes were needed) ---

/**
 * @title FuzeVesting
 * @notice Manages the vesting schedule for tokens purchased during the presale.
 */
contract FuzeVesting is Ownable2Step, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    // Events, State Variables, and Functions are unchanged...
    event Allocated(address indexed user, uint256 amount);
    event Claimed(address indexed user, uint256 amount);
    event TgeSet(uint256 timestamp);
    event AllocatorSet(address indexed allocator);

    IERC20 public immutable fuzeToken;
    uint256 public constant TGE_PERCENT = 10;
    uint256 public constant CLIFF_DURATION = 30 days;
    uint256 public constant VESTING_DURATION = 200 days;
    uint256 public constant PERCENT_DENOMINATOR = 100;

    address public allocator;
    uint256 public tgeTimestamp;
    uint256 public totalTokensAllocated;

    mapping(address => uint256) public totalAllocations;
    mapping(address => uint256) public claimedAmounts;

    modifier onlyAllocator() {
        require(msg.sender == allocator, "Vesting: Caller is not the allocator");
        _;
    }

    constructor(address _fuzeTokenAddress) Ownable(msg.sender) {
        require(_fuzeTokenAddress != address(0), "Vesting: Invalid token address");
        fuzeToken = IERC20(_fuzeTokenAddress);
    }

    function claim() external nonReentrant whenNotPaused {
        uint256 claimableAmount = calculateClaimable(msg.sender);
        require(claimableAmount > 0, "Vesting: No tokens available to claim");

        claimedAmounts[msg.sender] += claimableAmount;
        emit Claimed(msg.sender, claimableAmount);

        fuzeToken.safeTransfer(msg.sender, claimableAmount);
    }

    function calculateClaimable(address _user) public view returns (uint256) {
        if (block.timestamp < tgeTimestamp) return 0;

        uint256 userTotalAllocation = totalAllocations[_user];
        if (userTotalAllocation == 0) return 0;

        uint256 tgeAmount = (userTotalAllocation * TGE_PERCENT) / PERCENT_DENOMINATOR;
        uint256 vestedAmount = 0;
        uint256 cliffEndDate = tgeTimestamp + CLIFF_DURATION;

        if (block.timestamp > cliffEndDate) {
            uint256 vestingStartsAmount = userTotalAllocation - tgeAmount;
            uint256 vestingEndDate = cliffEndDate + VESTING_DURATION;

            if (block.timestamp >= vestingEndDate) {
                vestedAmount = vestingStartsAmount;
            } else {
                uint256 timeSinceCliffEnd = block.timestamp - cliffEndDate;
                vestedAmount = (vestingStartsAmount * timeSinceCliffEnd) / VESTING_DURATION;
            }
        }
        
        uint256 totalAvailable = tgeAmount + vestedAmount;
        uint256 alreadyClaimed = claimedAmounts[_user];
        
        if (totalAvailable <= alreadyClaimed) return 0;
        return totalAvailable - alreadyClaimed;
    }

    function allocate(address _user, uint256 _amount) external onlyAllocator {
        require(_user != address(0), "Vesting: Cannot allocate to zero address");
        require(_amount > 0, "Vesting: Amount must be greater than zero");

        totalAllocations[_user] += _amount;
        totalTokensAllocated += _amount;
        emit Allocated(_user, _amount);
    }

    function setAllocator(address _allocatorAddress) external onlyOwner {
        require(allocator == address(0), "Vesting: Allocator already set");
        require(_allocatorAddress != address(0), "Vesting: Invalid allocator address");
        allocator = _allocatorAddress;
        emit AllocatorSet(_allocatorAddress);
    }

    function setTgeTimestamp(uint256 _timestamp) external onlyOwner {
        require(tgeTimestamp == 0, "Vesting: TGE timestamp already set");
        require(_timestamp > block.timestamp, "Vesting: TGE must be in the future");
        tgeTimestamp = _timestamp;
        emit TgeSet(_timestamp);
    }

    function pause() external onlyOwner { _pause(); }
    function unpause() external onlyOwner { _unpause(); }
    
    function withdrawUnallocatedTokens() external onlyOwner {
        uint256 unallocated = fuzeToken.balanceOf(address(this)) - totalTokensAllocated;
        if (unallocated > 0) {
            fuzeToken.safeTransfer(owner(), unallocated);
        }
    }
}

// --- Presale Contract (Refactored and Fixed) ---

/**
 * @title FuzePresale
 * @notice Manages a multi-tier token presale, accepting ETH and stablecoins.
 */
contract FuzePresale is Ownable2Step, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Events, Structs, Constants, and State variables are mostly unchanged...
    event TokensPurchased(address indexed user, uint256 tokenAmount, uint256 usdValuePaid);
    event EthPriceSet(uint256 newPrice);
    event TreasurySet(address indexed newTreasury);
    event PaymentTokenSet(address indexed token, bool isAllowed);
    event FundsWithdrawn(address indexed token, uint256 amount);
    event EthWithdrawn(uint256 amount);
    
    struct Tier {
        uint256 cap;
        uint256 price;
    }
    
    uint256 public constant PRICE_PRECISION = 10**6;
    
    IFuzeVesting public immutable vestingContract;
    IERC20Metadata public immutable fuzeToken;
    Tier[] public tiers;
    uint256 public fuzeDecimalsUnit;

    uint256 public tokensSold;
    uint256 public ethUsdPrice;
    address public treasury;

    mapping(address => bool) public isPaymentTokenWhitelisted;

    constructor(
        address _fuzeTokenAddress,
        address _vestingContractAddress,
        address _initialTreasury
    ) Ownable(msg.sender) {
        fuzeToken = IERC20Metadata(_fuzeTokenAddress);
        vestingContract = IFuzeVesting(_vestingContractAddress);
        setTreasury(_initialTreasury);
        
        fuzeDecimalsUnit = 10**fuzeToken.decimals();

        tiers.push(Tier(25_000_000 * fuzeDecimalsUnit, 15_000));
        tiers.push(Tier(50_000_000 * fuzeDecimalsUnit, 20_000));
        tiers.push(Tier(75_000_000 * fuzeDecimalsUnit, 30_000));
        tiers.push(Tier(type(uint256).max, 50_000));
    }
    
    receive() external payable {
        buyWithEth();
    }

    /**
     * @notice Purchase FUZE tokens using ETH.
     * @dev FIX: Added nonReentrant guard and precise refund calculation.
     */
    function buyWithEth() public payable whenNotPaused nonReentrant {
        require(ethUsdPrice > 0, "Presale: ETH price not set");
        
        uint256 usdValue = (msg.value * ethUsdPrice) / 1 ether;
        require(usdValue > 0, "Presale: ETH amount too low");

        (uint256 tokensToAllocate, uint256 usdValuePaid) = _calculatePurchase(usdValue);
        
        _processPurchase(msg.sender, tokensToAllocate, usdValuePaid);

        // FIX: More precise refund calculation to prevent rounding errors.
        uint256 ethPaid = (usdValuePaid * 1 ether) / ethUsdPrice;
        if (msg.value > ethPaid) {
             uint256 ethToRefund = msg.value - ethPaid;
            (bool success,) = msg.sender.call{value: ethToRefund}("");
            require(success, "Presale: ETH refund failed");
        }
    }

    /**
     * @notice Purchase FUZE tokens using a whitelisted stablecoin.
     * @dev FIX: Patched critical "Allocate Before Pay" vulnerability. Added nonReentrant guard.
     */
    function buyWithStablecoin(
        address _paymentToken,
        uint256 _amount
    ) public whenNotPaused nonReentrant {
        require(isPaymentTokenWhitelisted[_paymentToken], "Presale: Payment token not whitelisted");
        
        // FIX: Use IERC20Metadata only for getting decimals.
        uint8 stablecoinDecimals = IERC20Metadata(_paymentToken).decimals();
        uint256 usdValue = (_amount * PRICE_PRECISION) / (10**stablecoinDecimals);
        require(usdValue > 0, "Presale: Amount too low");

        (uint256 tokensToAllocate, uint256 usdValuePaid) = _calculatePurchase(usdValue);
        
        // --- CRITICAL FIX: Secure payment BEFORE allocating tokens ---
        uint256 stablecoinToPay = (usdValuePaid * (10**stablecoinDecimals)) / PRICE_PRECISION;
        require(_amount >= stablecoinToPay, "Presale: Insufficient stablecoin amount");

        // FIX: Use IERC20 interface for SafeERC20 functions.
        IERC20 stablecoin = IERC20(_paymentToken);
        
        // 1. Secure funds from the user. Only pull the exact amount needed.
        stablecoin.safeTransferFrom(msg.sender, address(this), stablecoinToPay);

        // 2. Now that payment is secure, process the purchase.
        _processPurchase(msg.sender, tokensToAllocate, usdValuePaid);
        
        // 3. Refund any overpayment sent by the user.
        if (_amount > stablecoinToPay) {
            stablecoin.safeTransfer(msg.sender, _amount - stablecoinToPay);
        }
    }
    
    function _calculatePurchase(uint256 _usdValue) internal view returns (uint256 totalTokens, uint256 totalCost) {
        uint256 remainingUsd = _usdValue;
        uint256 currentTokensSold = tokensSold;
        
        for (uint256 i = 0; i < tiers.length; i++) {
            if (remainingUsd == 0) break;
            Tier memory tier = tiers[i];
            if (currentTokensSold >= tier.cap) continue;

            uint256 tokensAvailableInTier = tier.cap - currentTokensSold;
            uint256 costForAllInTier = (tokensAvailableInTier * tier.price) / fuzeDecimalsUnit;

            if (remainingUsd >= costForAllInTier) {
                totalTokens += tokensAvailableInTier;
                totalCost += costForAllInTier;
                remainingUsd -= costForAllInTier;
                currentTokensSold += tokensAvailableInTier;
            } else {
                uint256 tokensToBuy = (remainingUsd * fuzeDecimalsUnit) / tier.price;
                totalTokens += tokensToBuy;
                totalCost += remainingUsd;
                remainingUsd = 0;
            }
        }
    }
    
    function _processPurchase(address _buyer, uint256 _tokensToAllocate, uint256 _usdValuePaid) internal {
        require(_tokensToAllocate > 0, "Presale: Purchase amount is zero");
        
        tokensSold += _tokensToAllocate;
        vestingContract.allocate(_buyer, _tokensToAllocate);
        
        emit TokensPurchased(_buyer, _tokensToAllocate, _usdValuePaid);
    }
    
    // --- Owner Functions (Unchanged) ---
    function setEthUsdPrice(uint256 _priceWithPrecision) external onlyOwner {
        require(_priceWithPrecision > 0, "Presale: Price must be positive");
        ethUsdPrice = _priceWithPrecision;
        emit EthPriceSet(_priceWithPrecision);
    }

    function setTreasury(address _newTreasury) public onlyOwner {
        require(_newTreasury != address(0), "Presale: Invalid treasury address");
        treasury = _newTreasury;
        emit TreasurySet(_newTreasury);
    }
    
    function setPaymentToken(address _token, bool _isAllowed) external onlyOwner {
        isPaymentTokenWhitelisted[_token] = _isAllowed;
        emit PaymentTokenSet(_token, _isAllowed);
    }

    function withdrawEth() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "Presale: No ETH to withdraw");
        (bool success, ) = treasury.call{value: balance}("");
        require(success, "Presale: ETH withdrawal failed");
        emit EthWithdrawn(balance);
    }

    function withdrawErc20(address _tokenAddress) external onlyOwner {
        require(isPaymentTokenWhitelisted[_tokenAddress], "Presale: Cannot withdraw non-whitelisted token");
        IERC20 token = IERC20(_tokenAddress);
        uint256 balance = token.balanceOf(address(this));
        require(balance > 0, "Presale: No tokens to withdraw");
        token.safeTransfer(treasury, balance);
        emit FundsWithdrawn(_tokenAddress, balance);
    }

    function pause() external onlyOwner { _pause(); }
    function unpause() external onlyOwner { _unpause(); }
}
