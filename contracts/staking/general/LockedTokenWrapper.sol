// SPDX-License-Identifier: MIT

pragma solidity ^0.6.6;

import '../general/SafeERC20.sol';
import '../libraries/SafeMath.sol';

contract LockedTokenWrapper {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 public stakeToken;

    uint256 private constant _DURATION = 30 days;
    uint256 private _totalSupply;
    uint256 private _lockedTotalSupply;
    mapping (address => uint256) private _balances;
    mapping (address => uint256[]) private _lockedBalances;
    mapping (address => uint256[]) private _unlockTimes;

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev Total balance locked for a specific user.
     * @param account The address of the user we are checking locked balance of.
    **/
    function balanceLocked(address account) public view returns (uint256 lockedBalance) {
        for (uint256 i = 0; i < _lockedBalances[account].length; i++) {
            if (_unlockTimes[account][i] > block.timestamp) lockedBalance = lockedBalance.add(_lockedBalances[account][i]);
        }
    }

    /**
     * @dev Tokens available to be withdrawn (tokens in balance minus tokens in locked balance).
     * @param account Address to check available tokens for.
    **/
    function available(address account) public view returns (uint256) {
        return _balances[account].sub( balanceLocked(account) );
    }

    /**
     * @dev Check whether any batch can be unlocked.
     * @param account Address of the user to check unlock times for.
    **/
    function canUnlock(address account) public view returns (bool) {
        uint256[] memory unlockTimes = _unlockTimes[account];
        for (uint256 i = 0; i < unlockTimes.length; i++) {
            if (unlockTimes[i] <= block.timestamp) return true;
        }
    }

    function stake(uint256 amount) public virtual {
        _totalSupply = _totalSupply.add(amount);
        _balances[msg.sender] = _balances[msg.sender].add(amount);
        stakeToken.safeTransferFrom(msg.sender, address(this), amount);
    }

    /**
     * @dev Withdraw from staking rewards. Available balance is checked before this.
     * @param amount Amount to withdraw.
    **/
    function withdraw(uint256 amount) public virtual {
        _totalSupply = _totalSupply.sub(amount);
        _balances[msg.sender] = _balances[msg.sender].sub(amount);
        stakeToken.safeTransfer(msg.sender, amount);
    }
    
    /**
     * @dev Lock an amount of tokens for 30 days to begin receiving rewards on the BonusRewards contract.
     * @param amount Amount of COIN tokens to unlock.
    **/
    function lock(uint256 amount) public virtual {
        _lockedBalances[msg.sender].push(amount);
        _unlockTimes[msg.sender].push(block.timestamp.add(_DURATION));
        _lockedTotalSupply = _lockedTotalSupply.add(amount);
    }
    
    /**
     * @dev Getting all locked balances is needed for calculating earned on BonusRewards.
     * @param account Address of the user that we are checking locked balances of.
    **/
    function allLocked(address account) external view returns (uint256[] memory) {
        return _lockedBalances[account];
    }
    
    /**
     * @dev Getting all time is needed for calculating earned on BonusRewards.
     * @param account Address of the user that we are checking unlock times of.
    **/
    function allTimes(address account) external view returns (uint256[] memory) {
        return _unlockTimes[account];
    }
    
    /**
     * @dev Total supply of all locked tokens (acts as normal total supply on BonusRewards contract).
    **/
    function lockedTotalSupply() external view returns (uint256) {
        return _lockedTotalSupply;
    }
    
    /**
     * @dev Find full amount that can be unlocked and reward that equates to.
     * @param account Address that we are checking rewards of.
     * @param rewards Current (updated in modifier before this runs) reward balance of a user.
     * @return Amount of reward that will be paid out to users.
     * @return Array of new rewards values (old ones minus paid out ones).
    **/
    function _unlockable(address account, uint256[] memory rewards) internal returns (uint256, uint256[] memory) {
        uint256[] memory unlockTimes = _unlockTimes[account];
        uint256[] memory lockedBalances = _lockedBalances[account];
        
        uint256 rewardAmount;
        for (uint256 i = 0; i < unlockTimes.length; i++) {
            if (unlockTimes[i] <= block.timestamp) {
                rewardAmount = rewardAmount.add(rewards[i]);
                _lockedTotalSupply = _lockedTotalSupply.sub(lockedBalances[i]);
                
                lockedBalances[i] = 0;
                unlockTimes[i] = 0;
                rewards[i] = 0;
            }
        }
        
        _deleteLock(account, unlockTimes, lockedBalances);
        return (rewardAmount, rewards);
    }
    
    /**
     * @dev Weird structure with popping because we can't decrement dynamic array length in memory.
     * @param account Account that we're deleting elements of.
     * @param unlockTimes Unix timestamps of when each lock will be unlocked.
     * @param lockedBalances Amount of COIN locked in each batch.
    **/
    function _deleteLock(address account, uint256[] memory unlockTimes, uint256[] memory lockedBalances) internal 
    {
        // Keep track of how many elements are being removed to pop later.
        uint256 removed;
        
        for (uint256 i = 0; i < unlockTimes.length; i++) {
            if (unlockTimes[i] == 0) {
                // Must include - removed because the last element will be 0 after an element is deleted.
                unlockTimes[i] = unlockTimes[unlockTimes.length - 1 - removed];
                delete unlockTimes[unlockTimes.length - 1 - removed];
                
                lockedBalances[i] = lockedBalances[lockedBalances.length - 1 - removed];
                delete lockedBalances[lockedBalances.length - 1 - removed];
                
                removed++;
            }
        }
        
        _unlockTimes[account] = unlockTimes;
        _lockedBalances[account] = lockedBalances;
        
        for (uint256 i = 0; i < removed; i++) {
            _unlockTimes[account].pop();
            _lockedBalances[account].pop();
        }
    }
    
}