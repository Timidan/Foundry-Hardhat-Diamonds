// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {IDiamondCut} from "../../contracts/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "../../contracts/interfaces/IDiamondLoupe.sol";
import {DiamondUtils} from "./DiamondUtils.sol";

// Helper for building and executing diamond cuts using Foundry + forge inspect selectors.
abstract contract DiamondUpgradeHelper is DiamondUtils {
    // Build an Add cut for a facet by name (all selectors discovered via forge inspect)
    function buildAddCutByName(
        address facetAddress,
        string memory facetName
    ) internal returns (IDiamondCut.FacetCut memory cut) {
        bytes4[] memory selectors = generateSelectors(facetName);
        cut = IDiamondCut.FacetCut({
            facetAddress: facetAddress,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });
    }

    // Build Add cuts for multiple facets by names and addresses (arrays must match in length/order)
    function buildAddCutsByNames(
        address[] memory facetAddresses,
        string[] memory facetNames
    ) internal returns (IDiamondCut.FacetCut[] memory cuts) {
        require(facetAddresses.length == facetNames.length, "len mismatch");
        cuts = new IDiamondCut.FacetCut[](facetAddresses.length);
        for (uint256 i = 0; i < facetAddresses.length; i++) {
            cuts[i] = buildAddCutByName(facetAddresses[i], facetNames[i]);
        }
    }

    // Build a Replace cut for a facet by name, filtering out selectors that would replace to the same address.
    // Requires loupe support installed on the diamond.
    function buildReplaceCutByName(
        IDiamondLoupe loupe,
        address facetAddress,
        string memory facetName
    ) internal returns (IDiamondCut.FacetCut memory cut) {
        bytes4[] memory allSelectors = generateSelectors(facetName);
        // Count only selectors that currently exist AND are mapped to a different facet
        uint256 count = 0;
        for (uint256 i = 0; i < allSelectors.length; i++) {
            address current = loupe.facetAddress(allSelectors[i]);
            if (current != address(0) && current != facetAddress) {
                count++;
            }
        }
        bytes4[] memory filtered = new bytes4[](count);
        uint256 idx = 0;
        for (uint256 i = 0; i < allSelectors.length; i++) {
            address current = loupe.facetAddress(allSelectors[i]);
            if (current != address(0) && current != facetAddress) {
                filtered[idx++] = allSelectors[i];
            }
        }
        cut = IDiamondCut.FacetCut({
            facetAddress: facetAddress,
            action: IDiamondCut.FacetCutAction.Replace,
            functionSelectors: filtered
        });
    }

    // Build Replace cuts for multiple facets by names and addresses.
    function buildReplaceCutsByNames(
        IDiamondLoupe loupe,
        address[] memory facetAddresses,
        string[] memory facetNames
    ) internal returns (IDiamondCut.FacetCut[] memory cuts) {
        require(facetAddresses.length == facetNames.length, "len mismatch");
        cuts = new IDiamondCut.FacetCut[](facetAddresses.length);
        for (uint256 i = 0; i < facetAddresses.length; i++) {
            cuts[i] = buildReplaceCutByName(
                loupe,
                facetAddresses[i],
                facetNames[i]
            );
        }
    }

    // Build an Add cut for selectors that are missing on the diamond.
    function buildAddMissingCutByName(
        IDiamondLoupe loupe,
        address facetAddress,
        string memory facetName
    ) internal returns (IDiamondCut.FacetCut memory cut) {
        bytes4[] memory allSelectors = generateSelectors(facetName);
        uint256 count = 0;
        for (uint256 i = 0; i < allSelectors.length; i++) {
            if (loupe.facetAddress(allSelectors[i]) == address(0)) {
                count++;
            }
        }
        bytes4[] memory missing = new bytes4[](count);
        uint256 idx = 0;
        for (uint256 i = 0; i < allSelectors.length; i++) {
            if (loupe.facetAddress(allSelectors[i]) == address(0)) {
                missing[idx++] = allSelectors[i];
            }
        }
        cut = IDiamondCut.FacetCut({
            facetAddress: facetAddress,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: missing
        });
    }

    // Build both Replace and Add (missing) cuts to extend an existing facet implementation
    // with new selectors while migrating existing ones to a new facet address.
    function buildExtendCutsByName(
        IDiamondLoupe loupe,
        address facetAddress,
        string memory facetName
    ) internal returns (IDiamondCut.FacetCut[] memory cuts) {
        IDiamondCut.FacetCut memory rep = buildReplaceCutByName(loupe, facetAddress, facetName);
        IDiamondCut.FacetCut memory add = buildAddMissingCutByName(loupe, facetAddress, facetName);

        bool hasRep = rep.functionSelectors.length > 0;
        bool hasAdd = add.functionSelectors.length > 0;
        uint256 n = (hasRep ? 1 : 0) + (hasAdd ? 1 : 0);
        cuts = new IDiamondCut.FacetCut[](n);
        uint256 k = 0;
        if (hasRep) cuts[k++] = rep;
        if (hasAdd) cuts[k++] = add;
    }

    // Build a Remove cut for a list of selectors.
    function buildRemoveCut(
        bytes4[] memory selectors
    ) internal pure returns (IDiamondCut.FacetCut memory cut) {
        cut = IDiamondCut.FacetCut({
            facetAddress: address(0),
            action: IDiamondCut.FacetCutAction.Remove,
            functionSelectors: selectors
        });
    }

    // Execute a diamond cut with optional init.
    function executeDiamondCut(
        IDiamondCut diamond,
        IDiamondCut.FacetCut[] memory cuts,
        address init,
        bytes memory initCalldata
    ) internal {
        diamond.diamondCut(cuts, init, initCalldata);
    }
}
