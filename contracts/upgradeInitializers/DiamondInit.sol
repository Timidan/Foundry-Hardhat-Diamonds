// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LibDiamond} from "../libraries/LibDiamond.sol";
import {LibAppStorage} from "../libraries/LibAppStorage.sol";
import {IDiamondLoupe} from "../interfaces/IDiamondLoupe.sol";
import {IDiamondCut} from "../interfaces/IDiamondCut.sol";
import {IERC173} from "../interfaces/IERC173.sol";
import {IERC165} from "../interfaces/IERC165.sol";
import {IERC721, IERC721Metadata} from "../interfaces/IERC721.sol";
import {IERC20, IERC20Metadata} from "../interfaces/IERC20.sol";

contract DiamondInit {
    struct InitParams {
        string name;
        string symbol;
        string baseTokenURI;
        uint256 maxSupply;
        uint256 mintPrice;
        string erc20Name;
        string erc20Symbol;
        uint8 erc20Decimals;
        uint256 erc20MaxSupply;
        uint256 rewardRate;
        uint256 minStakeDuration;
        uint256 borrowFee;
        uint256 maxBorrowDuration;
        uint256 marketplaceFee;
    }

    function init(InitParams calldata params) external {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        ds.supportedInterfaces[type(IERC165).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondCut).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;
        ds.supportedInterfaces[type(IERC173).interfaceId] = true;
        ds.supportedInterfaces[type(IERC721).interfaceId] = true;
        ds.supportedInterfaces[type(IERC721Metadata).interfaceId] = true;
        ds.supportedInterfaces[type(IERC20).interfaceId] = true;
        ds.supportedInterfaces[type(IERC20Metadata).interfaceId] = true;

        LibAppStorage.NFTStorage storage nft = LibAppStorage.nftStorage();
        nft.name = params.name;
        nft.symbol = params.symbol;
        nft.baseTokenURI = params.baseTokenURI;
        nft.maxSupply = params.maxSupply;
        nft.mintPrice = params.mintPrice;
        nft.totalSupply = 0;
        nft.mintActive = false;
        nft.reentrancyStatus = LibAppStorage._NOT_ENTERED;

        LibAppStorage.ERC20Storage storage erc20 = LibAppStorage.erc20Storage();
        erc20.erc20Name = params.erc20Name;
        erc20.erc20Symbol = params.erc20Symbol;
        erc20.erc20Decimals = params.erc20Decimals;
        erc20.erc20TotalSupply = 0;
        erc20.erc20MaxSupply = params.erc20MaxSupply;

        LibAppStorage.StakingStorage storage staking = LibAppStorage.stakingStorage();
        staking.totalStaked = 0;
        staking.rewardRate = params.rewardRate;
        staking.minStakeDuration = params.minStakeDuration;

        LibAppStorage.BorrowStorage storage borrow = LibAppStorage.borrowStorage();
        borrow.borrowFee = params.borrowFee;
        borrow.maxBorrowDuration = params.maxBorrowDuration;

        LibAppStorage.MarketplaceStorage storage mkt = LibAppStorage.marketplaceStorage();
        mkt.marketplaceFee = params.marketplaceFee;
    }
}
