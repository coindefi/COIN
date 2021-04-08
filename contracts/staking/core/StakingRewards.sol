// SPDX-License-Identifier: MIT

pragma solidity ^0.6.6;

import '../general/Ownable.sol';
import '../general/LockedTokenWrapper.sol';
import '../libraries/Math.sol';
import '../libraries/SafeMath.sol';
import '../interfaces/IERC20.sol';
import '../interfaces/IBonusRewards.sol';
import '../interfaces/IRewardDistributionRecipient.sol';

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
 * @dev StakingRewards is the main Coin staking contract. COIN are deposited, receive rewards from fees of the system.
 *      Unlike the BonusRewards system, these tokens do not need to be locked to accumulate rewards. StakingRewards
 *      also keeps track of all locked balances and unlock times for the BonusRewards functionality.
**/
contract StakingRewards is LockedTokenWrapper, Ownable, IRewardDistributionRecipient {
    IERC20 public rewardToken;
    IBonusRewards public bonusRewards;
    address public reserve;
    address public rewardDistribution;
    uint256 public constant DURATION = 30 days;
    // what we divide percents by.
    uint256 private constant DENOMINATOR = 1000;

    uint256 public periodFinish = 0;
    uint256 public rewardRate = 0;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    // Percent of reserve we pull every 30 days. 1000 = 100%.
    uint256 public reservePercent;
    
    // Last time a reward was given--lastUpdateTime can change in updateReward to periodFinish so we can't use it.
    uint256 public lastRewardTime;
    
    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event Locked(address indexed user, uint256 amount);
    event ReservePercentChanged(uint256 oldPercent, uint256 newPercent);

    /**
     * @dev updateReward also updates rewards on the BonusRewards contract.
    **/
    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
            bonusRewards.updateReward(account);
        }
        _;
    }
    
    /**
     * @dev Update the lock balances and times of tokens. If a reward is to be paid, pay it.
    **/
    modifier updateLock(address account) {
        if ( canUnlock(account) ) {
            (uint256 reward, uint256[] memory newRewards) = _unlockable( account, bonusRewards.currentRewards(account) );
            if (reward > 0) bonusRewards.getReward(account, reward, newRewards);    
        }
        _;
    }

    constructor(address _stakeToken, address _rewardToken, address _bonusRewards, address _reserve, uint256 _reservePercent)
      public
    {
        Ownable.initialize();
        stakeToken = IERC20(_stakeToken);
        rewardToken = IERC20(_rewardToken);
        bonusRewards = IBonusRewards(_bonusRewards);
        reserve = _reserve;
        reservePercent = _reservePercent;
    }
    
    function setRewardDistribution(address _rewardDistribution)
        external
        override
        onlyOwner
    {
        rewardDistribution = _rewardDistribution;
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return Math.min(block.timestamp, periodFinish);
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalSupply() == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored.add(
                lastTimeRewardApplicable()
                    .sub(lastUpdateTime)
                    .mul(rewardRate)
                    .mul(1e18)
                    .div(totalSupply())
            );
    }

    function earned(address account) public view returns (uint256) {
        return
            balanceOf(account)
                .mul(rewardPerToken().sub(userRewardPerTokenPaid[account]))
                .div(1e18)
                .add(rewards[account]);
    }

    // stake visibility is public as overriding LPTokenWrapper's stake() function
    // updateReward must be before updateLock in all of these.
    function stake(uint256 amount) public override updateReward(msg.sender) updateLock(msg.sender) {
        require(amount > 0, "Cannot stake 0");
        super.stake(amount);
        emit Staked(msg.sender, amount);
    }

    // Require not locked.
    function withdraw(uint256 amount) public override updateReward(msg.sender) updateLock(msg.sender) {
        require(amount > 0, "Cannot withdraw 0");
        require(amount <= available(msg.sender), "Not enough available balance.");
        
        super.withdraw(amount);
        emit Withdrawn(msg.sender, amount);
    }

    /**
     * @dev Lock tokens being staked. Increases balance used by BonusRewards contract.
    **/
    function lock(uint256 amount) public override updateReward(msg.sender) updateLock(msg.sender) {
        require(amount <= available(msg.sender), "Not enough tokens available to lock.");
        super.lock(amount);
        bonusRewards.updateReward(msg.sender);
        emit Locked(msg.sender, amount);
    }

    function exit() external {
        withdraw(balanceOf(msg.sender));
        getReward();
    }

    // Calling will also get rewards from BonusRewards through the updateLock modifier.
    function getReward() public updateReward(msg.sender) updateLock(msg.sender) {
        uint256 reward = earned(msg.sender);
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardToken.safeTransfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    /**
     * @dev Big change here is to pull reward from the reserve based on a percent of the tokens it holds.
    **/
    function notifyRewardAmount()
        external
        override
        updateReward(address(0))
    {
        require(lastRewardTime <= block.timestamp.sub(DURATION), "You may not distribute reward within 30 days of last reward.");
        
        uint256 reward = getReserveReward();
        rewardToken.safeTransferFrom( address(reserve), address(this), reward );
        
        if (block.timestamp >= periodFinish) {
            rewardRate = reward.div(DURATION);
        } else {
            uint256 remaining = periodFinish.sub(block.timestamp);
            uint256 leftover = remaining.mul(rewardRate);
            rewardRate = reward.add(leftover).div(DURATION);
        }
        
        lastRewardTime = block.timestamp;
        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp.add(DURATION);
        emit RewardAdded(reward);
    }
    
    /**
     * @dev Find the amount of tokens to transfer into this contract.
    **/
    function getReserveReward()
      internal
      view
    returns (uint256 reserveReward)
    {
        uint256 reserveBalance = rewardToken.balanceOf( address(reserve) );
        reserveReward = reserveBalance * reservePercent / DENOMINATOR;
    }
    
    /**
     * @dev Owner can change the percent of the reserve that is to be distributed each month.
     * @param _reservePercent Percent of the reserve to distribute (1000 == 100%).
    **/
    function changeReservePercent(uint256 _reservePercent)
      external
      onlyOwner
    {
        emit ReservePercentChanged(reservePercent, _reservePercent);
        reservePercent = _reservePercent;
    }
    
}
