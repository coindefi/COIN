// SPDX-License-Identifier: MIT

pragma solidity ^0.6.6;

import './IRewardDistributionRecipient.sol';

interface IBonusRewards is IRewardDistributionRecipient {
  function initialize(address _rewardToken, address _stakeManager, address _rewardDistribution) external;
  function updateReward(address _user) external;
  function viewRewards(address _user) external view returns (uint256[] memory);
  function currentRewards(address _user) external view returns (uint256[] memory);
  function getReward(address _user, uint256 _rewards, uint256[] memory _newRewards) external;
}
