// SPDX-License-Identifier: MIT

pragma solidity ^0.6.6;

interface IStakingRewards {
  function lockedTotalSupply() external view returns (uint256);
  function allLocked(address _user) external view returns (uint256[] memory);
  function allTimes(address _user) external view returns (uint256[] memory);
}
