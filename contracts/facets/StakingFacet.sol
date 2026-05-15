// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IStakingFacet} from "../interfaces/IStakingFacet.sol";
import {IERC721} from "../interfaces/IERC721.sol";
import {LibAppStorage} from "../libraries/LibAppStorage.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";

contract StakingFacet is IStakingFacet {
    error TokenNotOwned(uint256 tokenId);
    error TokenNotStaked(uint256 tokenId);
    error TokenAlreadyStaked(uint256 tokenId);
    error MinStakeDurationNotMet(uint256 tokenId);
    error Unauthorized();

    event Staked(address indexed user, uint256 indexed tokenId, uint256 timestamp);
    event Unstaked(address indexed user, uint256 indexed tokenId, uint256 timestamp, uint256 reward);
    event RewardClaimed(address indexed user, uint256 amount);
    event RewardRateUpdated(uint256 oldRate, uint256 newRate);
    event MinStakeDurationUpdated(uint256 oldDuration, uint256 newDuration);

    function stake(uint256 tokenId) external {
        LibAppStorage.NFTStorage storage nft = LibAppStorage.nftStorage();
        LibAppStorage.StakingStorage storage stk = LibAppStorage.stakingStorage();

        if (stk.stakes[tokenId].staker != address(0)) revert TokenAlreadyStaked(tokenId);
        if (nft.owners[tokenId] != msg.sender) revert TokenNotOwned(tokenId);

        IERC721(address(this)).transferFrom(msg.sender, address(this), tokenId);

        stk.stakes[tokenId] = LibAppStorage.StakeInfo({
            staker: msg.sender,
            timestamp: block.timestamp,
            reward: 0
        });
        stk.totalStaked++;

        emit Staked(msg.sender, tokenId, block.timestamp);
    }

    function unstake(uint256 tokenId) external {
        LibAppStorage.NFTStorage storage nft = LibAppStorage.nftStorage();
        LibAppStorage.StakingStorage storage stk = LibAppStorage.stakingStorage();
        LibAppStorage.StakeInfo storage stake = stk.stakes[tokenId];

        if (stake.staker == address(0)) revert TokenNotStaked(tokenId);
        if (stake.staker != msg.sender) revert Unauthorized();
        if (block.timestamp < stake.timestamp + stk.minStakeDuration)
            revert MinStakeDurationNotMet(tokenId);

        uint256 reward = _calculateReward(tokenId);

        LibAppStorage.ERC20Storage storage erc20 = LibAppStorage.erc20Storage();
        erc20.erc20Balances[msg.sender] += reward;
        erc20.erc20TotalSupply += reward;

        nft.balances[msg.sender] += 1;
        nft.owners[tokenId] = msg.sender;

        delete stk.stakes[tokenId];
        stk.totalStaked--;

        emit Unstaked(msg.sender, tokenId, block.timestamp, reward);
    }

    function claimRewards() external {
        LibAppStorage.NFTStorage storage nft = LibAppStorage.nftStorage();
        LibAppStorage.StakingStorage storage stk = LibAppStorage.stakingStorage();
        LibAppStorage.ERC20Storage storage erc20 = LibAppStorage.erc20Storage();
        uint256 totalReward;

        uint256 supply = nft.totalSupply;
        for (uint256 i = 1; i <= supply; i++) {
            if (stk.stakes[i].staker == msg.sender) {
                uint256 reward = _calculateReward(i);
                if (reward > 0) {
                    stk.stakes[i].reward += reward;
                    stk.stakes[i].timestamp = block.timestamp;
                    totalReward += reward;
                }
            }
        }

        if (totalReward > 0) {
            erc20.erc20Balances[msg.sender] += totalReward;
            erc20.erc20TotalSupply += totalReward;
            emit RewardClaimed(msg.sender, totalReward);
        }
    }

    function getStakingInfo(uint256 tokenId) external view returns (address staker, uint256 timestamp, uint256 reward) {
        LibAppStorage.StakeInfo storage stake = LibAppStorage.stakingStorage().stakes[tokenId];
        return (stake.staker, stake.timestamp, stake.reward);
    }

    function getPendingReward(uint256 tokenId) external view returns (uint256) {
        return _calculateReward(tokenId);
    }

    function totalStaked() external view returns (uint256) {
        return LibAppStorage.stakingStorage().totalStaked;
    }

    function rewardRate() external view returns (uint256) {
        return LibAppStorage.stakingStorage().rewardRate;
    }

    function minStakeDuration() external view returns (uint256) {
        return LibAppStorage.stakingStorage().minStakeDuration;
    }

    function setRewardRate(uint256 _rate) external {
        LibDiamond.enforceIsContractOwner();
        uint256 oldRate = LibAppStorage.stakingStorage().rewardRate;
        LibAppStorage.stakingStorage().rewardRate = _rate;
        emit RewardRateUpdated(oldRate, _rate);
    }

    function setMinStakeDuration(uint256 _duration) external {
        LibDiamond.enforceIsContractOwner();
        uint256 oldDuration = LibAppStorage.stakingStorage().minStakeDuration;
        LibAppStorage.stakingStorage().minStakeDuration = _duration;
        emit MinStakeDurationUpdated(oldDuration, _duration);
    }

    function _calculateReward(uint256 tokenId) internal view returns (uint256) {
        LibAppStorage.StakingStorage storage stk = LibAppStorage.stakingStorage();
        LibAppStorage.StakeInfo storage stake = stk.stakes[tokenId];

        if (stake.staker == address(0)) return 0;

        uint256 duration = block.timestamp - stake.timestamp;
        return (duration * stk.rewardRate) / 1 days;
    }
}
