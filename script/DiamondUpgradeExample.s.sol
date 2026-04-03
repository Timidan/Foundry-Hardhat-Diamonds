// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import {IDiamondCut} from "../contracts/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "../contracts/interfaces/IDiamondLoupe.sol";
import {DiamondUpgradeHelper} from "../test/helpers/DiamondUpgradeHelper.sol";

contract DiamondUpgradeExample is Script, DiamondUpgradeHelper {
    function run() external {
        // Define all inputs explicitly here:
        address diamond = address(0x000000000000000000000000000000000000dEaD); // TODO set

        // Configure adds
        address[] memory addFacetAddresses = new address[](0);
        string[] memory addFacetNames = new string[](0);

        // Configure replacements
        address[] memory replaceFacetAddresses = new address[](0);
        string[] memory replaceFacetNames = new string[](0);

        // Configure removals
        bytes4[] memory removeSelectors = new bytes4[](0);

        // Optional init
        address init = address(0);
        bytes memory initCalldata = hex"";

        // Build cuts
        IDiamondCut.FacetCut[] memory addCuts = buildAddCutsByNames(
            addFacetAddresses,
            addFacetNames
        );
        IDiamondCut.FacetCut[] memory repCuts = buildReplaceCutsByNames(
            IDiamondLoupe(diamond),
            replaceFacetAddresses,
            replaceFacetNames
        );
        uint256 extra = removeSelectors.length > 0 ? 1 : 0;
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](
            addCuts.length + repCuts.length + extra
        );
        uint256 k = 0;
        for (uint256 i = 0; i < addCuts.length; i++) cuts[k++] = addCuts[i];
        for (uint256 j = 0; j < repCuts.length; j++) cuts[k++] = repCuts[j];
        if (removeSelectors.length > 0)
            cuts[k++] = buildRemoveCut(removeSelectors);

        // Execute
        vm.startBroadcast();
        executeDiamondCut(IDiamondCut(diamond), cuts, init, initCalldata);
        vm.stopBroadcast();
    }
}


