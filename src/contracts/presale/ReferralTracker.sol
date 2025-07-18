// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title ReferralTracker
 * @dev Contract for tracking referrals and distributing rewards
 */
contract ReferralTracker is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct ReferralInfo {
        uint256 totalReferrals;      // Number of unique referrals
        uint256 totalVolume;         // Total volume generated by referrals
        uint256 totalRewards;        // Total rewards earned
        uint256 claimedRewards;      // Rewards already claimed
        mapping(address => bool) hasReferred; // Track if an address has been referred
    }

    // Mapping from referrer to their referral info
    mapping(address => ReferralInfo) public referrers;
    
    // Mapping from referee to their referrer
    mapping(address => address) public referrerOf;
    
    // Referral rate (3%)
    uint256 public referralRate = 30; // 30 = 3%
    
    // Base token (USDT, USDC, etc.)
    address public baseToken;
    
    // Total referral volume
    uint256 public totalReferralVolume;
    
    // Total referral rewards
    uint256 public totalReferralRewards;
    
    // Total claimed rewards
    uint256 public totalClaimedRewards;

    event ReferralAdded(
        address indexed referrer,
        address indexed referee,
        uint256 timestamp
    );
    
    event ReferralPurchase(
        address indexed referrer,
        address indexed referee,
        uint256 amount,
        uint256 reward
    );
    
    event RewardsClaimed(
        address indexed referrer,
        uint256 amount
    );
    
    event ReferralRateUpdated(uint256 newRate);

    constructor(address _baseToken) {
        baseToken = _baseToken;
    }

    /**
     * @dev Add a referral
     * @param referrer Address of the referrer
     * @param referee Address of the referee
     */
    function addReferral(address referrer, address referee) external {
        require(referrer != address(0), "Invalid referrer");
        require(referee != address(0), "Invalid referee");
        require(referrer != referee, "Cannot refer yourself");
        require(referrerOf[referee] == address(0), "Already referred");
        
        // Store referral relationship
        referrerOf[referee] = referrer;
        
        // Update referrer stats
        ReferralInfo storage info = referrers[referrer];
        info.totalReferrals++;
        info.hasReferred[referee] = true;
        
        emit ReferralAdded(referrer, referee, block.timestamp);
    }

    /**
     * @dev Record a purchase made by a referred user
     * @param buyer Address of the buyer
     * @param amount Amount of the purchase in base token
     */
    function recordPurchase(address buyer, uint256 amount) external onlyOwner {
        address referrer = referrerOf[buyer];
        
        // If buyer has a referrer, calculate and track reward
        if (referrer != address(0)) {
            uint256 reward = (amount * referralRate) / 1000;
            
            // Update referrer stats
            ReferralInfo storage info = referrers[referrer];
            info.totalVolume += amount;
            info.totalRewards += reward;
            
            // Update global stats
            totalReferralVolume += amount;
            totalReferralRewards += reward;
            
            emit ReferralPurchase(referrer, buyer, amount, reward);
        }
    }

    /**
     * @dev Claim referral rewards
     */
    function claimRewards() external nonReentrant {
        address referrer = msg.sender;
        ReferralInfo storage info = referrers[referrer];
        
        uint256 unclaimedRewards = info.totalRewards - info.claimedRewards;
        require(unclaimedRewards > 0, "No rewards to claim");
        
        // Update claimed amount
        info.claimedRewards += unclaimedRewards;
        totalClaimedRewards += unclaimedRewards;
        
        // Transfer rewards
        IERC20(baseToken).safeTransfer(referrer, unclaimedRewards);
        
        emit RewardsClaimed(referrer, unclaimedRewards);
    }

    /**
     * @dev Get unclaimed rewards for a referrer
     * @param referrer Address of the referrer
     */
    function getUnclaimedRewards(address referrer) external view returns (uint256) {
        ReferralInfo storage info = referrers[referrer];
        return info.totalRewards - info.claimedRewards;
    }

    /**
     * @dev Get referral stats for a referrer
     * @param referrer Address of the referrer
     */
    function getReferralStats(address referrer) external view returns (
        uint256 totalReferrals,
        uint256 totalVolume,
        uint256 totalRewards,
        uint256 claimedRewards,
        uint256 unclaimedRewards
    ) {
        ReferralInfo storage info = referrers[referrer];
        return (
            info.totalReferrals,
            info.totalVolume,
            info.totalRewards,
            info.claimedRewards,
            info.totalRewards - info.claimedRewards
        );
    }

    /**
     * @dev Check if an address has been referred by a specific referrer
     * @param referrer Address of the referrer
     * @param referee Address of the referee
     */
    function hasReferred(address referrer, address referee) external view returns (bool) {
        return referrers[referrer].hasReferred[referee];
    }

    /**
     * @dev Update referral rate (owner only)
     * @param newRate New rate (in 0.1% increments, e.g., 30 = 3%)
     */
    function updateReferralRate(uint256 newRate) external onlyOwner {
        require(newRate <= 100, "Rate too high"); // Max 10%
        referralRate = newRate;
        emit ReferralRateUpdated(newRate);
    }

    /**
     * @dev Update base token (owner only)
     * @param newBaseToken New base token address
     */
    function updateBaseToken(address newBaseToken) external onlyOwner {
        require(newBaseToken != address(0), "Invalid base token");
        baseToken = newBaseToken;
    }

    /**
     * @dev Emergency function to rescue tokens accidentally sent to this contract (owner only)
     * @param token Token address
     * @param amount Amount to rescue
     */
    function rescueTokens(address token, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(owner(), amount);
    }
}