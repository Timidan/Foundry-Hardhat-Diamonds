// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IStakingFacet {
    function stake(uint256 tokenId) external;
    function unstake(uint256 tokenId) external;
    function claimRewards() external;
    function getStakingInfo(uint256 tokenId) external view returns (address staker, uint256 timestamp, uint256 reward);
    function getPendingReward(uint256 tokenId) external view returns (uint256);
    function totalStaked() external view returns (uint256);
    function rewardRate() external view returns (uint256);
    function minStakeDuration() external view returns (uint256);
}
