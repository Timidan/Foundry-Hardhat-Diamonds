// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IStaking {
    function stake(uint256 tokenId) external;
    function unstake(uint256 tokenId) external;
    function claimRewards() external;
    function getStakedBy(uint256 tokenId) external view returns (address);
}