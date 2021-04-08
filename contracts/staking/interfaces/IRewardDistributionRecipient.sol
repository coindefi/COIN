// SPDX-License-Identifier: MIT

pragma solidity ^0.6.6;

interface IRewardDistributionRecipient {
    function notifyRewardAmount() external;
    function setRewardDistribution(address rewardDistribution) external;
}
