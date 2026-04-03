// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/interfaces/IDiamondLoupe.sol";
import "../contracts/interfaces/IERC165.sol";
import "../contracts/interfaces/IERC173.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "../contracts/facets/ERC721Facet.sol";
import "../contracts/Diamond.sol";

import "./helpers/DiamondUpgradeHelper.sol";

contract DiamondDeployer is DiamondUpgradeHelper {

    Diamond diamond; // diamond proxy contract
    DiamondCutFacet dCutFacet; // facet with diamondCut policy
    DiamondLoupeFacet dLoupe; // facet providing introspection
    OwnershipFacet ownerF; // facet enabling owner transfer

    ///  Deploy the base diamond and add the initial loupe+ownership facets.
    function testDeployDiamond() public {
        // deploy facet implementations
        dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(address(this), address(dCutFacet));
        dLoupe = new DiamondLoupeFacet();
        ownerF = new OwnershipFacet();

        // Upgrade diamond with facets using explicit function selectors (no FFI dependency)
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

        executeDiamondCut(IDiamondCut(address(diamond)), cuts, address(0), "");

        //call a function
        DiamondLoupeFacet(address(diamond)).facetAddresses();
    }

    /// Deploy diamond, add base facets, then add ERC721 facet and verify ERC721 behavior.
    function testDeployAndUpgradeDiamondWithERC721Facet() public {

        // deploy base facets and diamond
        dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(address(this), address(dCutFacet));
        dLoupe = new DiamondLoupeFacet();
        ownerF = new OwnershipFacet();

        // add DiamondLoupeFacet and OwnershipFacet with explicit selectors
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

        executeDiamondCut(IDiamondCut(address(diamond)), cuts, address(0), "");

        // deploy ERC721 facet and cut into diamond (no FFI dependency)
        ERC721Facet erc721Facet = new ERC721Facet();
        IDiamondCut.FacetCut[] memory ercCut = new IDiamondCut.FacetCut[](1);

        // Specify ERC721 function selectors to add to diamond.
        bytes4[] memory ercSelectors = new bytes4[](12);
        ercSelectors[0] = IERC721.balanceOf.selector;
        ercSelectors[1] = IERC721.ownerOf.selector;
        ercSelectors[2] = IERC721.safeTransferFrom.selector;
        ercSelectors[3] = IERC721.transferFrom.selector;
        ercSelectors[4] = IERC721.approve.selector;
        ercSelectors[5] = IERC721.setApprovalForAll.selector;
        ercSelectors[6] = IERC721.getApproved.selector;
        ercSelectors[7] = IERC721.isApprovedForAll.selector;
        ercSelectors[8] = bytes4(keccak256("name()"));
        ercSelectors[9] = bytes4(keccak256("symbol()"));
        ercSelectors[10] = bytes4(keccak256("setMetadata(string,string)"));
        ercSelectors[11] = bytes4(keccak256("mint(address,uint256)"));

        ercCut[0] = IDiamondCut.FacetCut({
            facetAddress: address(erc721Facet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: ercSelectors
        });

        // Upgrade operation: add ERC721Facet selectors into the diamond.
        executeDiamondCut(IDiamondCut(address(diamond)), ercCut, address(0), "");

        // Use diamond with ERC721Facet ABI
        ERC721Facet erc = ERC721Facet(address(diamond));

        // Set metadata and mint value
        erc.setMetadata("Diamond721", "D721");
        erc.mint(address(this), 100);

        assertEq(erc.balanceOf(address(this)), 1);
        assertEq(erc.ownerOf(100), address(this));

        // transfer works through diamond
        erc.transferFrom(address(this), address(0x123), 100);
        assertEq(erc.balanceOf(address(0x123)), 1);
        assertEq(erc.ownerOf(100), address(0x123));
    }
}

