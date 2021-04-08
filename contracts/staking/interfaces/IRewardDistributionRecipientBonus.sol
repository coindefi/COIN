// SPDX-License-Identifier: MIT

pragma solidity ^0.6.6;

interface IRewardDistributionRecipientBonus {
    function notifyRewardAmount(uint256 amount) external;
    function setRewardDistribution(address rewardDistribution) external;
}
