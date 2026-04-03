// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/interfaces/IDiamondLoupe.sol";
import "../contracts/interfaces/IERC165.sol";
import "../contracts/interfaces/IERC173.sol";
import "../contracts/interfaces/IERC721.sol";
import "../contracts/interfaces/IBorrower.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "../contracts/facets/ERC721Facet.sol";
import "../contracts/facets/ERC721BorrowerFacet.sol";
import "../contracts/Diamond.sol";
import "../contracts/upgradeInitializers/DiamondInit.sol";

import "./helpers/DiamondUpgradeHelper.sol";

contract ERC721BorrowerFacetTest is DiamondUpgradeHelper {
    Diamond diamond;
    DiamondCutFacet dCutFacet;
    DiamondLoupeFacet dLoupe;
    OwnershipFacet ownerF;
    ERC721Facet erc721F;
    ERC721BorrowerFacet borrowerF;
    DiamondInit dInit;

    address[] signers = [address(this), address(0x1), address(0x2), address(0x3)];

    function setUp() public {
        // Deploy facets
        dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(address(this), address(dCutFacet));
        dLoupe = new DiamondLoupeFacet();
        ownerF = new OwnershipFacet();
        erc721F = new ERC721Facet();
        borrowerF = new ERC721BorrowerFacet();
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

        // Add borrower facet
        bytes4[] memory borrowerSelectors = new bytes4[](3);
        borrowerSelectors[0] = IBorrower.borrow.selector;
        borrowerSelectors[1] = IBorrower.returnBorrowed.selector;
        borrowerSelectors[2] = IBorrower.getBorrowedBy.selector;

        IDiamondCut.FacetCut[] memory borrowerCuts = new IDiamondCut.FacetCut[](1);
        borrowerCuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(borrowerF),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: borrowerSelectors
        });

        IDiamondCut(address(diamond)).diamondCut(borrowerCuts, address(0), "");
    }

    function testBorrowing() public {
        address owner = address(0x100);
        address borrower = address(0x200);
        uint256 tokenId = 1;
        uint256 duration = 3600; // 1 hour

        // Mint NFT to owner
        ERC721Facet(address(diamond)).mint(owner, tokenId);

        // Approve diamond to transfer NFT
        vm.prank(owner);
        IERC721(address(diamond)).approve(address(diamond), tokenId);

        // Borrow NFT
        vm.prank(borrower);
        IBorrower(address(diamond)).borrow(tokenId, duration);

        // Check borrowing state
        address borrowedBy = IBorrower(address(diamond)).getBorrowedBy(tokenId);
        assertEq(borrowedBy, borrower);

        // Check NFT ownership (should still be owner)
        address currentOwner = IERC721(address(diamond)).ownerOf(tokenId);
        assertEq(currentOwner, owner);

        // Return NFT
        vm.prank(borrower);
        IBorrower(address(diamond)).returnBorrowed(tokenId);

        // Check borrowing state cleared
        borrowedBy = IBorrower(address(diamond)).getBorrowedBy(tokenId);
        assertEq(borrowedBy, address(0));
    }

    function testBorrowExpiry() public {
        address owner = address(0x100);
        address borrower = address(0x200);
        uint256 tokenId = 1;
        uint256 duration = 100;

        // Mint and borrow NFT
        ERC721Facet(address(diamond)).mint(owner, tokenId);
        vm.prank(owner);
        IERC721(address(diamond)).approve(address(diamond), tokenId);
        vm.prank(borrower);
        IBorrower(address(diamond)).borrow(tokenId, duration);

        // Fast forward past expiry
        vm.warp(block.timestamp + duration + 1);

        // Should be able to return even after expiry
        vm.prank(borrower);
        IBorrower(address(diamond)).returnBorrowed(tokenId);

        // Check state cleared
        address borrowedBy = IBorrower(address(diamond)).getBorrowedBy(tokenId);
        assertEq(borrowedBy, address(0));
    }
}