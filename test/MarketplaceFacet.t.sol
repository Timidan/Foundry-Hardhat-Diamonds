// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/interfaces/IDiamondLoupe.sol";
import "../contracts/interfaces/IERC165.sol";
import "../contracts/interfaces/IERC173.sol";
import "../contracts/interfaces/IERC721.sol";
import "../contracts/interfaces/IERC20.sol";
import "../contracts/interfaces/IMarketplace.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "../contracts/facets/ERC721Facet.sol";
import "../contracts/facets/ERC20Facet.sol";
import "../contracts/facets/MarketplaceFacet.sol";
import "../contracts/Diamond.sol";
import "../contracts/upgradeInitializers/DiamondInit.sol";

import "./helpers/DiamondUpgradeHelper.sol";

contract MarketplaceFacetTest is DiamondUpgradeHelper {
    Diamond diamond;
    DiamondCutFacet dCutFacet;
    DiamondLoupeFacet dLoupe;
    OwnershipFacet ownerF;
    ERC721Facet erc721F;
    ERC20Facet erc20F;
    MarketplaceFacet marketplaceF;
    DiamondInit dInit;

    address[] signers = [address(this), address(0x1), address(0x2), address(0x3)];

    function setUp() public {
        // Deploy facets
        dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(address(this), address(dCutFacet));
        dLoupe = new DiamondLoupeFacet();
        ownerF = new OwnershipFacet();
        erc721F = new ERC721Facet();
        erc20F = new ERC20Facet();
        marketplaceF = new MarketplaceFacet();
        dInit = new DiamondInit();

        // Add base facets
        bytes4[] memory loupeSelectors = new bytes4[](5);
        loupeSelectors[0] = IDiamondLoupe.facets.selector;
        loupeSelectors[1] = IDiamondLoupe.facetFunctionSelectors.selector;
        loupeSelectors[2] = IDiamondLoupe.facetAddresses.selector;
        loupeSelectors[3] = IDiamondLoupe.facetAddress.selector;
        loupeSelectors[4] = IERC165.supportsInterface.selector;

        bytes4[] memory ownershipSelectors = new bytes4[](2);
        ownershipSelectors[0] = IERC173.transferOwnership.selector;
        ownershipSelectors[1] = IERC173.owner.selector;

        bytes4[] memory erc721Selectors = new bytes4[](9);
        erc721Selectors[0] = IERC721.balanceOf.selector;
        erc721Selectors[1] = IERC721.ownerOf.selector;
        erc721Selectors[2] = IERC721.safeTransferFrom.selector;
        erc721Selectors[3] = IERC721.transferFrom.selector;
        erc721Selectors[4] = IERC721.approve.selector;         // 0x095ea7b3 — ERC721 wins
        erc721Selectors[5] = IERC721.setApprovalForAll.selector;
        erc721Selectors[6] = IERC721.getApproved.selector;
        erc721Selectors[7] = IERC721.isApprovedForAll.selector;
        erc721Selectors[8] = erc721F.mint.selector;

        // NOTE: ERC20 approve (0x095ea7b3) is intentionally excluded here.
        // It collides with ERC721 approve. The marketplace bypasses the
        // allowance flow entirely, so the buyer never needs to call approve().
        bytes4[] memory erc20Selectors = new bytes4[](5);
        erc20Selectors[0] = IERC20.totalSupply.selector;
        // erc20Selectors[1] = IERC20.balanceOf.selector;
        erc20Selectors[2] = IERC20.transfer.selector;
        erc20Selectors[3] = IERC20.allowance.selector;
        erc20Selectors[4] = erc20F.setBalance.selector;
        // erc20F.approve  ← EXCLUDED: collides with IERC721.approve (0x095ea7b3)
        // erc20F.transferFrom ← EXCLUDED: collides with IERC721.transferFrom (0x23b872dd)

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](4);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(dLoupe),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: loupeSelectors
        });
        cuts[1] = IDiamondCut.FacetCut({
            facetAddress: address(ownerF),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: ownershipSelectors
        });
        cuts[2] = IDiamondCut.FacetCut({
            facetAddress: address(erc721F),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: erc721Selectors
        });
        cuts[3] = IDiamondCut.FacetCut({
            facetAddress: address(erc20F),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: erc20Selectors
        });

        // Initialize diamond
        bytes memory initData = abi.encodeWithSelector(DiamondInit.init.selector, signers);
        IDiamondCut(address(diamond)).diamondCut(cuts, address(dInit), initData);

        // Add marketplace facet
        bytes4[] memory marketplaceSelectors = new bytes4[](3);
        marketplaceSelectors[0] = IMarketplace.list.selector;
        marketplaceSelectors[1] = IMarketplace.buy.selector;
        marketplaceSelectors[2] = IMarketplace.getListing.selector;

        IDiamondCut.FacetCut[] memory marketplaceCuts = new IDiamondCut.FacetCut[](1);
        marketplaceCuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(marketplaceF),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: marketplaceSelectors
        });

        IDiamondCut(address(diamond)).diamondCut(marketplaceCuts, address(0), "");
    }

    function testMarketplace() public {
        address seller = address(0x100);
        address buyer = address(0x200);
        uint256 tokenId = 1;
        uint256 price = 1000;

        // Mint NFT to seller and ERC20 tokens to buyer
        ERC721Facet(address(diamond)).mint(seller, tokenId);
        ERC20Facet(address(diamond)).setBalance(buyer, price);

        // Seller approves the diamond (marketplace) to transfer the NFT
        vm.prank(seller);
        IERC721(address(diamond)).approve(address(diamond), tokenId);

        // Seller lists the NFT
        vm.prank(seller);
        IMarketplace(address(diamond)).list(tokenId, price);

        // Verify listing
        uint256 listedPrice = IMarketplace(address(diamond)).getListing(tokenId);
        assertEq(listedPrice, price);

        // Buyer purchases the NFT
        vm.prank(buyer);
        IMarketplace(address(diamond)).buy(tokenId);

        // NFT ownership transferred to buyer
        address newOwner = IERC721(address(diamond)).ownerOf(tokenId);
        assertEq(newOwner, buyer);

        // ERC20 tokens transferred to seller
        assertEq(ERC20Facet(address(diamond)).balanceOf(seller), price);
        assertEq(ERC20Facet(address(diamond)).balanceOf(buyer), 0);

        // Listing cleared
        listedPrice = IMarketplace(address(diamond)).getListing(tokenId);
        assertEq(listedPrice, 0);
    }
}