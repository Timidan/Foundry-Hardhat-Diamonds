// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/interfaces/IDiamondLoupe.sol";
import "../contracts/interfaces/IERC165.sol";
import "../contracts/interfaces/IERC173.sol";
import "../contracts/interfaces/IERC721.sol";
import "../contracts/interfaces/ISVG.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "../contracts/facets/ERC721Facet.sol";
import "../contracts/facets/SVGFacet.sol";
import "../contracts/Diamond.sol";
import "../contracts/upgradeInitializers/DiamondInit.sol";

import "./helpers/DiamondUpgradeHelper.sol";

contract SVGFacetTest is DiamondUpgradeHelper {
    Diamond diamond;
    DiamondCutFacet dCutFacet;
    DiamondLoupeFacet dLoupe;
    OwnershipFacet ownerF;
    ERC721Facet erc721F;
    SVGFacet svgF;
    DiamondInit dInit;

    address[] signers = [address(this), address(0x1), address(0x2), address(0x3)];

    function setUp() public {
        // Deploy facets
        dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(address(this), address(dCutFacet));
        dLoupe = new DiamondLoupeFacet();
        ownerF = new OwnershipFacet();
        erc721F = new ERC721Facet();
        svgF = new SVGFacet();
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
        erc721Selectors[4] = IERC721.approve.selector;
        erc721Selectors[5] = IERC721.setApprovalForAll.selector;
        erc721Selectors[6] = IERC721.getApproved.selector;
        erc721Selectors[7] = IERC721.isApprovedForAll.selector;
        erc721Selectors[8] = erc721F.mint.selector;

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](3);
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

        // Initialize diamond
        bytes memory initData = abi.encodeWithSelector(DiamondInit.init.selector, signers);
        IDiamondCut(address(diamond)).diamondCut(cuts, address(dInit), initData);

        // Add SVG facet
        bytes4[] memory svgSelectors = new bytes4[](1);
        svgSelectors[0] = ISVG.tokenURI.selector;

        IDiamondCut.FacetCut[] memory svgCuts = new IDiamondCut.FacetCut[](1);
        svgCuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(svgF),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: svgSelectors
        });

        IDiamondCut(address(diamond)).diamondCut(svgCuts, address(0), "");
    }

    function testTokenURI() public {
        address user = address(0x100);
        uint256 tokenId = 1;

        // Mint NFT
        ERC721Facet(address(diamond)).mint(user, tokenId);

        // Get token URI
        string memory uri = ISVG(address(diamond)).tokenURI(tokenId);

        // Check that URI contains expected data
        assertTrue(bytes(uri).length > 0);
        // Simplified check - just ensure it's not empty
    }
}