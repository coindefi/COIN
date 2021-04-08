// SPDX-License-Identifier: MIT

pragma solidity ^0.6.6;

import '../general/Ownable.sol';
import '../general/SafeERC20.sol';
import '../libraries/SafeMath.sol';
import '../interfaces/IERC20.sol';

/**
 * @dev Coin reserve for all COIN fees and extra tokens submitted to begin with. Pays out to StakingRewards and BonusRewards.
**/
contract Reserve is Ownable {
    using SafeERC20 for IERC20;

    IERC20 public coinToken;
    address public stakingRewards;
    address public bonusRewards;

    event StakingRewardsChanged(address _oldStakingRewards, address _newStakingRewards);
    event BonusRewardsChanged(address _oldBonusRewards, address _newBonusRewards);

    constructor(address _coinToken, address _stakingRewards, address _bonusRewards)
      public
    {
        Ownable.initialize();
        coinToken = IERC20(_coinToken);
        stakingRewards = _stakingRewards;
        bonusRewards = _bonusRewards;
    }

    /**
     * @dev Must approve both rewards contracts to withdraw tokens from the reserve.
    **/
    function approve()
      external
    {
        coinToken.safeApprove( stakingRewards, uint256(-1) );
        coinToken.safeApprove( bonusRewards, uint256(-1) );
    }

    /**
     * @dev Owner can change the StakingRewards contract.
    **/
    function changeStakingRewards(address _stakingRewards)
      external
      onlyOwner
    {
        require(_stakingRewards != address(0), "StakingRewards must not be address(0).");
        emit StakingRewardsChanged(stakingRewards, _stakingRewards);
        stakingRewards = _stakingRewards;
    }

    /**
     * @dev Owner can change the BonusRewards contract.
    **/
    function changeBonusRewards(address _bonusRewards)
      external
      onlyOwner
    {
        require(_bonusRewards != address(0), "BonusRewards must not be address(0).");
        emit BonusRewardsChanged(bonusRewards, _bonusRewards);
        bonusRewards = _bonusRewards;
    }

}
