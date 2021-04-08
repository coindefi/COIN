// SPDX-License-Identifier: MIT

pragma solidity ^0.6.6;

import '../general/Ownable.sol';
import '../general/SafeERC20.sol';
import '../libraries/Math.sol';
import '../libraries/SafeMath.sol';
import '../interfaces/IERC20.sol';
import '../interfaces/IStakingRewards.sol';
import '../interfaces/IRewardDistributionRecipientBonus.sol';

/**
 * @dev RewardManager is nearly the exact same contract as Utilization Farm.
 *      Only difference is the initialize function instead of constructor.
**/

/**
* MIT License
* ===========
*
* Copyright (c) 2020 Synthetix
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in all
* copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
*/

/**
 * @dev BonusRewards provides another stream for users staking on Coin's StakingRewards contract.
 *      While it is a separate stream, all balance and supply data is taken from the StakingRewards contract.
**/
contract BonusRewards is Ownable, IRewardDistributionRecipientBonus {
    using SafeMath for *;
    using SafeERC20 for IERC20;

    IStakingRewards public stakingRewards;

    // Reward token is 0 if Ether is the reward.
    IERC20 public rewardToken;
    address public rewardDistribution;
    uint256 public constant DURATION = 7 days;

    uint256 public periodFinish = 0;
    uint256 public rewardRate = 0;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    
    mapping(address => uint256[]) public userRewardPerTokenPaid;
    mapping(address => uint256[]) public rewards;

    event RewardAdded(uint256 reward);
    event BalanceAdded(address indexed user, uint256 amount);
    event BalanceWithdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardDistributionChanged(address oldRewardDistribution, address newRewardDistribution);

    modifier onlyRewardDistribution() {
        require(msg.sender == rewardDistribution, "Caller is not reward distribution.");
        _;
    }
    
    /**
     * @dev Extra restrictions are needed because arbitrary values can be passed by sender to manipulate rewards.
    **/
    modifier onlyStakingRewards() {
        require(msg.sender == address(stakingRewards), "Caller is not StakingRewards contract.");
        _;
    }
    
    modifier onlyStakeOrReward() {
        require(msg.sender == address(stakingRewards) || msg.sender == rewardDistribution, "Caller must be stake or reward.");
        _;
    }

    function initialize(address _rewardToken, address _stakingRewards, address _rewardDistribution) external
    {
        Ownable.initialize();
        require(address(stakingRewards) == address(0), "Contract is already initialized.");
        stakingRewards = IStakingRewards(_stakingRewards);
        rewardToken = IERC20(_rewardToken);
        rewardDistribution = _rewardDistribution;
    }

    /**
     * @dev updateReward replaces the modifier on most SNX contracts. The normal staking contract calls this in its modifier.
     *      Has a different strategy from normal SNX to account for each locked batch separately.
     * @param account Address that we are updating.
    **/
    function updateReward(address account)
      public
    {
        rewardPerTokenStored = rewardPerToken(0);
        lastUpdateTime = lastTimeRewardApplicable(0);
        
        if (account != address(0)) {
            uint256[] memory lockedBalances = stakingRewards.allLocked(account);
            uint256[] memory unlockTimes = stakingRewards.allTimes(account);
            
            for (uint256 i = 0; i < lockedBalances.length; i++) {
                
                if (i >= rewards[account].length) {
                    rewards[account].push(0);
                    userRewardPerTokenPaid[account].push(rewardPerTokenStored);
                }
                
                rewards[account][i] = _earned(lockedBalances[i], 
                                             unlockTimes[i], 
                                             userRewardPerTokenPaid[account][i],
                                             rewards[account][i]);
                                             
                userRewardPerTokenPaid[account][i] = rewardPerTokenStored;
            
            }
        }
    }

    /**
     * @dev Reward user. Only called when locked tokens are unlocked. Restricted to StakingRewards.
     * @param user Address that we are paying out rewards to.
     * @param rewardAmount Amount of COIN rewards we are paying.
     * @param newRewards Array of the new rewards list (with unlocked amounts popped).
    **/
    function getReward(address payable user, uint256 rewardAmount, uint256[] calldata newRewards)
      external
      onlyStakingRewards
    {
        _deleteRewards(user, newRewards);
        rewardToken.safeTransfer(user, rewardAmount);
        emit RewardPaid(user, rewardAmount);
    }

    /**
     * @dev unlockTime added here because tokens must stop being rewarded once they're unlocked.
     * @param unlockTime Unix timestamp of when tokens can be unlocked.
    **/
    function lastTimeRewardApplicable(uint256 unlockTime) public view returns (uint256) {
        // Unlock time will be 0 if we're doing general updates.
        uint256 firstMin = unlockTime == 0 ? periodFinish : Math.min(unlockTime, periodFinish);
        return Math.min(firstMin, block.timestamp);
    }

    /**
     * @dev unlockTime must be passed in here to lastTimeRewardApplicable.
     * @param unlockTime The timestamp that this batch unlocks.
    **/
    function rewardPerToken(uint256 unlockTime) public view returns (uint256) {
        if (stakingRewards.lockedTotalSupply() == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored.add(lastTimeRewardApplicable(unlockTime)
                    .sub(lastUpdateTime)
                    .mul(rewardRate)
                    .mul(1e18)
                    .div(stakingRewards.lockedTotalSupply())
            );
    }
    
    /**
     * @dev Frontend can view rewards including ones that have not been pushed yet.
     * @param account Address that we're viewing rewards for.
    **/
    function viewRewards(address account)
      external
      view
    returns (uint256[] memory)
    {
        uint256[] memory lockedBalances = stakingRewards.allLocked(account);
        uint256[] memory unlockTimes = stakingRewards.allTimes(account);
        
        // We need the dynamic array's length to match the others.
        uint256[] memory tempRewards = stakingRewards.allLocked(account);
        uint256 rewardsLength = rewards[account].length;
        
        for (uint256 i = 0; i < lockedBalances.length; i++) {
            uint256 tempPaid;
            uint256 tempReward;
            
            // Only set real amounts if they are already in storage--otherwise 0.
            // This happens when a lock has happened without any interaction after.
            if (i < rewardsLength) {
                tempPaid = userRewardPerTokenPaid[account][i];
                tempReward = rewards[account][i];
            }
            
            tempRewards[i] = _earned(lockedBalances[i], 
                                    unlockTimes[i], 
                                    tempPaid,
                                    tempReward);
        }
        
        return tempRewards;
    }
    
    /**
     * @dev StakingRewards needs to be able to see the current rewards on the contract. Cheaper than view.
     * @param account Address that we are viewing rewards of.
    **/
    function currentRewards(address account)
      external
      view
    returns (uint256[] memory)
    {
        return rewards[account];
    }
      
    /**
     * @dev Because most variables are coming from StakingRewards, we must pass them in here.
     * @param lockedBalance Amount of balance locked for this specific batch.
     * @param unlockTime The time that this specific batch unlocks.
     * @param rewardPerTokenPaid What has already been paid on this specific batch.
     * @param rewarded What this batch has already been rewarded.
    **/
    function _earned(uint256 lockedBalance, uint256 unlockTime, uint256 rewardPerTokenPaid, uint256 rewarded) 
      internal
      view 
    returns (uint256) 
    {
        return lockedBalance
            .mul(rewardPerToken(unlockTime)
            .sub(rewardPerTokenPaid))
            .div(1e18)
            .add(rewarded);
    }

    /**
     * @dev Weird structure with popping because we can't decrement dynamic array length in memory.
     * @param user Address that we are deleting rewards of.
     * @param newRewards Array of the user's newRewards (old ones minus unlocked).
    **/
    function _deleteRewards(address user, uint256[] memory newRewards)
      internal
    {
        // Keep track of how many elements are being removed to pop later.
        uint256 removed;
        
        for (uint256 i = 0; i < newRewards.length; i++) {
            if (newRewards[i] == 0) {
                newRewards[i] = newRewards[newRewards.length - 1 - removed];
                delete newRewards[newRewards.length - 1 - removed];
                removed++;
            }
        }
        
        rewards[user] = newRewards;
        for (uint256 i = 0; i < removed; i++) rewards[user].pop();
    }

    function setRewardDistribution(address _rewardDistribution)
        external
        override
        onlyOwner
    {
        emit RewardDistributionChanged(rewardDistribution, _rewardDistribution);
        rewardDistribution = _rewardDistribution;
    }

    /**
     * @dev Main difference from SNX is that the modifier for update is changed into a function.
    **/
    function notifyRewardAmount(uint256 reward)
        external
        override
        onlyRewardDistribution
    {
        updateReward(address(0));
        
        rewardToken.safeTransferFrom(msg.sender, address(this), reward);
        
        if (block.timestamp >= periodFinish) {
            rewardRate = reward.div(DURATION);
        } else {
            uint256 remaining = periodFinish.sub(block.timestamp);
            uint256 leftover = remaining.mul(rewardRate);
            rewardRate = reward.add(leftover).div(DURATION);
        }
        
        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp.add(DURATION);
        emit RewardAdded(reward);
    }
}
