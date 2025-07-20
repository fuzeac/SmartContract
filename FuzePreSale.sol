// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/**
 * @title FuzePreSale
 * @dev This contract manages the pre-sale for the FUZE token.
 * It handles purchases with a stablecoin and implements a specific
 * vesting schedule with an initial unlock, a cliff, and a linear vesting period.
 * Refactored to fix critical calculation bug and improve claim gas efficiency.
 */
contract FuzePreSale is Ownable, AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    struct UserInfo {
        uint256 totalStableCoinAmount; // Total stablecoin amount spent by the user
        uint256 timesOfBuy; // Number of times the user has bought tokens
    }

    struct OrderInfo {
        uint256 stableCoinAmount; // Amount of stablecoin spent in this purchase
        uint256 tokenAmount; // Amount of tokens bought
        uint256 claimedTokenAmount; // Amount of tokens claimed by the user for this order
        uint256 boughtDate; // Timestamp when the tokens were bought
    }

    // --- Roles & Constants ---
    bytes32 public immutable PROJECTOWNER = keccak256("PROJECTOWNER");
    uint256 public constant DAY = 86400; // Seconds in a day

    // --- Token & Sale Configuration ---
    IERC20 public token; // The FUZE token being sold
    IERC20 public immutable stableCoin; // The stablecoin used for purchase
    uint256 public immutable rate; // FUZE token wei per whole stablecoin unit
    uint256 public immutable maxUserBuyingLimit; // Max purchase amount in stablecoin per user (in stablecoin's smallest unit)
    uint256 public immutable stableCoinDecimalsUnit; // The unit for stablecoin decimals (e.g., 1e6 for USDT)

    // --- Vesting Parameters ---
    uint256 public immutable tgeUnlockPercent; // Percentage of tokens unlocked at TGE (e.g., 10 for 10%)
    uint256 public immutable cliffPeriod;      // Cliff duration in days
    uint256 public immutable vestingPeriod;    // Linear vesting duration in days (after the cliff)

    // --- Sale State ---
    uint256 public startDate;
    uint256 public endDate;
    uint256 public totalTokenForSale;
    uint256 public totalTokenBought;
    bool public saleClosed;

    uint256 public currentTokenBalance;
    uint256 public totalClaimedToken;
    uint256 public totalStableCoinRaised;
    uint256 public totalWithdrawnStableCoin;

    // --- Mappings ---
    mapping(address => UserInfo) public users;
    mapping(address => mapping(uint256 => OrderInfo)) public orders;

    // --- Events ---
    event TokenBought(address indexed userAddress, uint256 stableCoinAmount, uint256 tokenAmount, uint256 orderIndex);
    event TokenWithdrawn(address indexed userAddress, uint256 tokenAmount);
    event TokenClaimed(address indexed userAddress, uint256 tokenAmount, uint256 orderIndex);
    event StableCoinWithdrawn(address indexed receiver, uint256 stableCoinAmount);
    event SaleStarted(uint256 tokenAmount, uint256 startTimestamp, uint256 endTimestamp);
    event SaleEnded(uint256 endTimestamp);

    /**
     * @dev Sets up the contract with sale and vesting parameters.
     * @param _tokenAddress The address of the FUZE token.
     * @param _stableCoinAddress The address of the stablecoin token.
     * @param _stableCoinDecimals The number of decimals for the stablecoin (e.g., 6 for USDT).
     * @param _rate The number of FUZE token wei per whole stablecoin unit.
     * @param _maxUserBuyingLimit The maximum stablecoin a single user can spend (in whole units, e.g., 1000 for 1000 USDT).
     * @param _projectOwner The address that will manage the sale.
     * @param _tgeUnlockPercent The percentage of tokens unlocked at purchase.
     * @param _cliffPeriod The cliff period in days.
     * @param _vestingPeriod The linear vesting period in days that follows the cliff.
     */
    constructor(
        address _tokenAddress,
        address _stableCoinAddress,
        uint8 _stableCoinDecimals,
        uint256 _rate,
        uint256 _maxUserBuyingLimit,
        address _projectOwner,
        uint256 _tgeUnlockPercent,
        uint256 _cliffPeriod,
        uint256 _vestingPeriod
    ) Ownable(_projectOwner) {
        require(_tgeUnlockPercent <= 100, "TGE percent cannot exceed 100");
        require(_stableCoinDecimals > 0 && _stableCoinDecimals <= 18, "Invalid stablecoin decimals");

        token = IERC20(_tokenAddress);
        stableCoin = IERC20(_stableCoinAddress);
        rate = _rate;
        stableCoinDecimalsUnit = 10**_stableCoinDecimals;
        maxUserBuyingLimit = _maxUserBuyingLimit * stableCoinDecimalsUnit;
        
        tgeUnlockPercent = _tgeUnlockPercent;
        cliffPeriod = _cliffPeriod;
        vestingPeriod = _vestingPeriod;

        _grantRole(DEFAULT_ADMIN_ROLE, _projectOwner);
        _grantRole(PROJECTOWNER, _projectOwner);
    }

    // --- Fallback Functions ---
    receive() external payable { revert("ETH is not accepted"); }
    fallback() external payable { revert("Function does not exist"); }

    // --- Owner Functions ---

    function withdrawStableCoin(address _receiver) external onlyRole(PROJECTOWNER) {
        uint256 withdrawAmount = stableCoin.balanceOf(address(this));
        require(withdrawAmount > 0, "No stablecoin to withdraw");
        
        totalWithdrawnStableCoin += withdrawAmount;
        totalStableCoinRaised -= withdrawAmount;
        stableCoin.safeTransfer(_receiver, withdrawAmount);

        emit StableCoinWithdrawn(_receiver, withdrawAmount);
    }

    function withdrawUnsoldTokens() external onlyRole(PROJECTOWNER) {
        require(block.timestamp >= endDate || saleClosed, "Sale must be closed");
        uint256 unsoldTokens = token.balanceOf(address(this)) - (totalTokenBought - totalClaimedToken);
        require(unsoldTokens > 0, "No unsold tokens");

        currentTokenBalance -= unsoldTokens;
        token.safeTransfer(msg.sender, unsoldTokens);
        
        emit TokenWithdrawn(msg.sender, unsoldTokens);
    }

    function startSale(uint256 _tokenAmount, uint256 _periodSaleInDays) external onlyRole(PROJECTOWNER) {
        require(startDate == 0, "Sale already started");
        require(_tokenAmount > 0, "Token amount must be > 0");
        require(_periodSaleInDays > 0, "Sale period must be > 0");

        totalTokenForSale = _tokenAmount;
        currentTokenBalance = _tokenAmount;
        startDate = block.timestamp;
        endDate = startDate + (_periodSaleInDays * DAY);
        
        token.safeTransferFrom(msg.sender, address(this), _tokenAmount);
        
        emit SaleStarted(_tokenAmount, startDate, endDate);
    }

    function endSale() external onlyRole(PROJECTOWNER) {
        require(startDate > 0, "Sale has not started");
        require(!saleClosed, "Sale already closed");
        
        saleClosed = true;
        endDate = block.timestamp;
        emit SaleEnded(block.timestamp);
    }

    // --- Public User Functions ---

    function buyToken(uint256 _stableAmount) external whenNotPaused {
        require(startDate > 0 && block.timestamp < endDate, "Sale is not active");
        require(!saleClosed, "Sale is closed");
        require(_stableAmount > 0, "Stablecoin amount must be > 0");

        // [FIXED] Correctly calculates token amount using the proper decimals.
        uint256 tokenAmount = (_stableAmount * rate) / stableCoinDecimalsUnit;
        
        require(tokenAmount <= currentTokenBalance, "Insufficient tokens for sale");
        
        UserInfo storage user = users[msg.sender];
        if (maxUserBuyingLimit > 0) {
            require(user.totalStableCoinAmount + _stableAmount <= maxUserBuyingLimit, "Exceeds max user buy limit");
        }

        totalStableCoinRaised += _stableAmount;
        user.totalStableCoinAmount += _stableAmount;
        user.timesOfBuy++;
        
        uint256 currentOrderIndex = user.timesOfBuy;
        orders[msg.sender][currentOrderIndex] = OrderInfo({
            boughtDate: block.timestamp,
            stableCoinAmount: _stableAmount,
            tokenAmount: tokenAmount,
            claimedTokenAmount: 0
        });

        totalTokenBought += tokenAmount;
        currentTokenBalance -= tokenAmount;
        
        stableCoin.safeTransferFrom(msg.sender, address(this), _stableAmount);

        emit TokenBought(msg.sender, _stableAmount, tokenAmount, currentOrderIndex);
    }

    function claimToken(uint256 _orderIndex) public nonReentrant {
        uint256 claimAmount = calculateClaimableAmount(msg.sender, _orderIndex);
        require(claimAmount > 0, "No tokens to claim for this order");

        orders[msg.sender][_orderIndex].claimedTokenAmount += claimAmount;
        totalClaimedToken += claimAmount;
        token.safeTransfer(msg.sender, claimAmount);

        emit TokenClaimed(msg.sender, claimAmount, _orderIndex);
    }

    /**
     * @dev Claims tokens from multiple orders at once to save gas and avoid block gas limits.
     * @param _orderIndexes An array of order numbers to be claimed.
     */
    function claimMultipleOrders(uint256[] calldata _orderIndexes) external nonReentrant {
        uint256 totalClaimAmount = 0;
        uint256 ordersLength = _orderIndexes.length;
        require(ordersLength > 0, "No orders specified");

        for (uint256 i = 0; i < ordersLength; i++) {
            uint256 orderIndex = _orderIndexes[i];
            uint256 claimAmount = calculateClaimableAmount(msg.sender, orderIndex);
            if (claimAmount > 0) {
                totalClaimAmount += claimAmount;
                orders[msg.sender][orderIndex].claimedTokenAmount += claimAmount;
                emit TokenClaimed(msg.sender, claimAmount, orderIndex);
            }
        }
        
        require(totalClaimAmount > 0, "Total claimable amount is zero");
        
        totalClaimedToken += totalClaimAmount;
        token.safeTransfer(msg.sender, totalClaimAmount);
    }

    // --- View Functions ---

    function calculateClaimableAmount(address _userAddress, uint256 _orderIndex) public view returns (uint256) {
        OrderInfo memory order = orders[_userAddress][_orderIndex];
        if (order.tokenAmount == 0) return 0; // Order does not exist

        // 1. TGE Unlock
        uint256 tgeAmount = (order.tokenAmount * tgeUnlockPercent) / 100;

        // 2. Vesting Calculation
        uint256 vestedAmount = 0;
        uint256 currentTime = block.timestamp;
        uint256 cliffEndDate = order.boughtDate + (cliffPeriod * DAY);

        if (currentTime > cliffEndDate) {
            uint256 vestingStartsAmount = order.tokenAmount - tgeAmount;
            uint256 vestingEndDate = cliffEndDate + (vestingPeriod * DAY);

            if (currentTime >= vestingEndDate) {
                vestedAmount = vestingStartsAmount; // Full vesting
            } else {
                uint256 timeSinceCliffEnd = currentTime - cliffEndDate;
                vestedAmount = (vestingStartsAmount * timeSinceCliffEnd) / (vestingPeriod * DAY);
            }
        }
        
        uint256 totalClaimable = tgeAmount + vestedAmount;
        if (totalClaimable > order.tokenAmount) totalClaimable = order.tokenAmount;
        
        uint256 alreadyClaimed = order.claimedTokenAmount;
        if (alreadyClaimed >= totalClaimable) return 0;

        return totalClaimable - alreadyClaimed;
    }

    function checkTotalClaimableAmount(address _userAddress) public view returns (uint256) {
        uint256 totalClaimAmount = 0;
        uint256 userOrderCount = users[_userAddress].timesOfBuy;
        for (uint256 i = 1; i <= userOrderCount; i++) {
            totalClaimAmount += calculateClaimableAmount(_userAddress, i);
        }
        return totalClaimAmount;
    }

    function getOrderInfo(address _userAddress, uint256 _orderIndex) public view returns (OrderInfo memory) {
        return orders[_userAddress][_orderIndex];
    }
}
