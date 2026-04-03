// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/interfaces/IDiamondLoupe.sol";
import "../contracts/interfaces/IERC165.sol";
import "../contracts/interfaces/IERC173.sol";
import "../contracts/interfaces/IERC20.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "../contracts/facets/ERC20Facet.sol";
import "../contracts/Diamond.sol";
import "../contracts/upgradeInitializers/DiamondInit.sol";

import "./helpers/DiamondUpgradeHelper.sol";

contract ERC20FacetTest is DiamondUpgradeHelper {
    Diamond diamond;
    DiamondCutFacet dCutFacet;
    DiamondLoupeFacet dLoupe;
    OwnershipFacet ownerF;
    ERC20Facet erc20F;
    DiamondInit dInit;

    address[] signers = [address(this), address(0x1), address(0x2), address(0x3)];

    function setUp() public {
        // Deploy facets
        dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(address(this), address(dCutFacet));
        dLoupe = new DiamondLoupeFacet();
        ownerF = new OwnershipFacet();
        erc20F = new ERC20Facet();
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

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](2);
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

        // Initialize diamond
        bytes memory initData = abi.encodeWithSelector(DiamondInit.init.selector, signers);
        IDiamondCut(address(diamond)).diamondCut(cuts, address(dInit), initData);

        // Add ERC20 facet
        bytes4[] memory erc20Selectors = new bytes4[](8);
        erc20Selectors[0] = IERC20.totalSupply.selector;
        erc20Selectors[1] = IERC20.balanceOf.selector;
        erc20Selectors[2] = IERC20.transfer.selector;
        erc20Selectors[3] = IERC20.allowance.selector;
        erc20Selectors[4] = IERC20.approve.selector;
        erc20Selectors[5] = IERC20.transferFrom.selector;
        erc20Selectors[6] = erc20F.mint.selector;
        erc20Selectors[7] = erc20F.name.selector;

        IDiamondCut.FacetCut[] memory erc20Cuts = new IDiamondCut.FacetCut[](1);
        erc20Cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(erc20F),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: erc20Selectors
        });

        IDiamondCut(address(diamond)).diamondCut(erc20Cuts, address(0), "");
    }

    function testERC20Basic() public {
        address user1 = address(0x100);
        address user2 = address(0x200);

        // Mint tokens to user1
        ERC20Facet(address(diamond)).mint(user1, 1000);

        // Check balance
        uint256 balance = IERC20(address(diamond)).balanceOf(user1);
        assertEq(balance, 1000);

        // Transfer tokens
        vm.prank(user1);
        bool success = IERC20(address(diamond)).transfer(user2, 500);
        assertTrue(success);

        // Check balances after transfer
        assertEq(IERC20(address(diamond)).balanceOf(user1), 500);
        assertEq(IERC20(address(diamond)).balanceOf(user2), 500);
    }

    function testERC20ApproveTransferFrom() public {
        address owner = address(0x100);
        address spender = address(0x200);
        address recipient = address(0x300);

        // Mint tokens to owner
        ERC20Facet(address(diamond)).mint(owner, 1000);

        // Approve spender
        vm.prank(owner);
        bool success = IERC20(address(diamond)).approve(spender, 500);
        assertTrue(success);

        // Check allowance
        uint256 allowance = IERC20(address(diamond)).allowance(owner, spender);
        assertEq(allowance, 500);

        // Transfer from
        vm.prank(spender);
        success = IERC20(address(diamond)).transferFrom(owner, recipient, 300);
        assertTrue(success);

        // Check balances and allowance
        assertEq(IERC20(address(diamond)).balanceOf(owner), 700);
        assertEq(IERC20(address(diamond)).balanceOf(recipient), 300);
        assertEq(IERC20(address(diamond)).allowance(owner, spender), 200);
    }
}