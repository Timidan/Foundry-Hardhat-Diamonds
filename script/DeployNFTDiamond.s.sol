// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import {IDiamondCut} from "../contracts/interfaces/IDiamondCut.sol";
import {Diamond} from "../contracts/Diamond.sol";
import {DiamondCutFacet} from "../contracts/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../contracts/facets/DiamondLoupeFacet.sol";
import {OwnershipFacet} from "../contracts/facets/OwnershipFacet.sol";
import {ERC721Facet} from "../contracts/facets/ERC721Facet.sol";
import {MintFacet} from "../contracts/facets/MintFacet.sol";
import {NFTAdminFacet} from "../contracts/facets/NFTAdminFacet.sol";
import {ERC20Facet} from "../contracts/facets/ERC20Facet.sol";
import {OnchainSVGFacet} from "../contracts/facets/OnchainSVGFacet.sol";
import {StakingFacet} from "../contracts/facets/StakingFacet.sol";
import {MultisigFacet} from "../contracts/facets/MultisigFacet.sol";
import {BorrowerFacet} from "../contracts/facets/BorrowerFacet.sol";
import {MarketplaceFacet} from "../contracts/facets/MarketplaceFacet.sol";
import {DiamondInit} from "../contracts/upgradeInitializers/DiamondInit.sol";
import {DiamondUpgradeHelper} from "../test/helpers/DiamondUpgradeHelper.sol";

contract DeployNFTDiamond is Script, DiamondUpgradeHelper {
    function run() external {
        vm.startBroadcast();

        DiamondCutFacet diamondCutFacet = new DiamondCutFacet();
        Diamond diamond = new Diamond(msg.sender, address(diamondCutFacet));

        console.log("DiamondCutFacet:", address(diamondCutFacet));
        console.log("Diamond:", address(diamond));

        IDiamondCut.FacetCut[] memory allCuts = _buildCuts(address(diamond));

        DiamondInit diamondInit = new DiamondInit();
        console.log("DiamondInit:", address(diamondInit));

        bytes memory initCalldata = _encodeInit(diamondInit);

        executeDiamondCut(
            IDiamondCut(address(diamond)),
            allCuts,
            address(diamondInit),
            initCalldata
        );

        vm.stopBroadcast();

        console.log("Deployment complete!");
        console.log("Diamond:", address(diamond));
    }

    function _buildCuts(
        address diamond
    ) internal returns (IDiamondCut.FacetCut[] memory) {
        DiamondLoupeFacet diamondLoupeFacet = new DiamondLoupeFacet();
        OwnershipFacet ownershipFacet = new OwnershipFacet();
        ERC721Facet erc721Facet = new ERC721Facet();
        MintFacet mintFacet = new MintFacet();
        NFTAdminFacet adminFacet = new NFTAdminFacet();
        ERC20Facet erc20Facet = new ERC20Facet();
        OnchainSVGFacet svgFacet = new OnchainSVGFacet();
        StakingFacet stakingFacet = new StakingFacet();
        MultisigFacet multisigFacet = new MultisigFacet();
        BorrowerFacet borrowerFacet = new BorrowerFacet();
        MarketplaceFacet marketplaceFacet = new MarketplaceFacet();

        console.log("DiamondLoupeFacet:", address(diamondLoupeFacet));
        console.log("OwnershipFacet:", address(ownershipFacet));
        console.log("ERC721Facet:", address(erc721Facet));
        console.log("MintFacet:", address(mintFacet));
        console.log("NFTAdminFacet:", address(adminFacet));
        console.log("ERC20Facet:", address(erc20Facet));
        console.log("OnchainSVGFacet:", address(svgFacet));
        console.log("StakingFacet:", address(stakingFacet));
        console.log("MultisigFacet:", address(multisigFacet));
        console.log("BorrowerFacet:", address(borrowerFacet));
        console.log("MarketplaceFacet:", address(marketplaceFacet));

        address[] memory addrs = new address[](11);
        addrs[0] = address(diamondLoupeFacet);
        addrs[1] = address(ownershipFacet);
        addrs[2] = address(erc721Facet);
        addrs[3] = address(mintFacet);
        addrs[4] = address(adminFacet);
        addrs[5] = address(erc20Facet);
        addrs[6] = address(svgFacet);
        addrs[7] = address(stakingFacet);
        addrs[8] = address(multisigFacet);
        addrs[9] = address(borrowerFacet);
        addrs[10] = address(marketplaceFacet);

        string[] memory names = new string[](11);
        names[0] = "DiamondLoupeFacet";
        names[1] = "OwnershipFacet";
        names[2] = "ERC721Facet";
        names[3] = "MintFacet";
        names[4] = "NFTAdminFacet";
        names[5] = "ERC20Facet";
        names[6] = "OnchainSVGFacet";
        names[7] = "StakingFacet";
        names[8] = "MultisigFacet";
        names[9] = "BorrowerFacet";
        names[10] = "MarketplaceFacet";

        return buildAddCutsByNames(addrs, names);
    }

    function _encodeInit(
        DiamondInit diamondInit
    ) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(
            diamondInit.init.selector,
            DiamondInit.InitParams({
                name: "Diamond NFT",
                symbol: "DNFT",
                baseTokenURI: "https://ipfs.io/ipfs/QmRvSoppQ5MKfsT4p5Snheae1DG3Af2NhYXWpKNZBvz2Eo/00001.png",
                maxSupply: 10000,
                mintPrice: 0.05 ether,
                erc20Name: "Diamond Token",
                erc20Symbol: "DTKN",
                erc20Decimals: 18,
                erc20MaxSupply: 1000000 ether,
                rewardRate: 10 ether,
                minStakeDuration: 1 days,
                borrowFee: 0.01 ether,
                maxBorrowDuration: 30 days,
                marketplaceFee: 250
            })
        );
    }
}
