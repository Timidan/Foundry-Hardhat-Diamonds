// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/interfaces/IDiamondLoupe.sol";
import "../contracts/interfaces/IERC165.sol";
import "../contracts/interfaces/IERC173.sol";
import "../contracts/interfaces/IMultisig.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "../contracts/facets/MultisigFacet.sol";
import "../contracts/Diamond.sol";
import "../contracts/upgradeInitializers/DiamondInit.sol";

import "./helpers/DiamondUpgradeHelper.sol";

contract MultisigFacetTest is DiamondUpgradeHelper {
    Diamond diamond;
    DiamondCutFacet dCutFacet;
    DiamondLoupeFacet dLoupe;
    OwnershipFacet ownerF;
    MultisigFacet multisigF;
    DiamondInit dInit;

    address[] signers = [address(this), address(0x1), address(0x2), address(0x3)];

    function setUp() public {
        // Deploy facets
        dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(address(this), address(dCutFacet));
        dLoupe = new DiamondLoupeFacet();
        ownerF = new OwnershipFacet();
        multisigF = new MultisigFacet();
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

        // Initialize diamond with signers
        bytes memory initData = abi.encodeWithSelector(DiamondInit.init.selector, signers);
        IDiamondCut(address(diamond)).diamondCut(cuts, address(dInit), initData);

        // Add multisig facet
        bytes4[] memory multisigSelectors = new bytes4[](4);
        multisigSelectors[0] = IMultisig.addSigner.selector;
        multisigSelectors[1] = IMultisig.removeSigner.selector;
        multisigSelectors[2] = IMultisig.signTransaction.selector;
        multisigSelectors[3] = IMultisig.executeTransaction.selector;

        IDiamondCut.FacetCut[] memory multisigCuts = new IDiamondCut.FacetCut[](1);
        multisigCuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(multisigF),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: multisigSelectors
        });

        IDiamondCut(address(diamond)).diamondCut(multisigCuts, address(0), "");
    }

    function testAddSigner() public {
        address newSigner = address(0x4);

        // Signer 1 proposes adding new signer
        vm.prank(signers[0]);
        IMultisig(address(diamond)).addSigner(newSigner);

        // Signer 2 approves
        vm.prank(signers[1]);
        bytes32 txHash = keccak256(abi.encodePacked("addSigner", newSigner));
        IMultisig(address(diamond)).signTransaction(txHash);

        // Signer 3 approves (should execute automatically)
        vm.prank(signers[2]);
        IMultisig(address(diamond)).signTransaction(txHash);
    }

    function testSignTransaction() public {
        address newSigner = address(0x4);

        // Start transaction to add signer
        vm.prank(signers[0]);
        IMultisig(address(diamond)).addSigner(newSigner);

        // Sign with another signer
        vm.prank(signers[1]);
        bytes32 txHash = keccak256(abi.encodePacked("addSigner", newSigner));
        IMultisig(address(diamond)).signTransaction(txHash);
    }

    function testRemoveSigner() public {
        address signerToRemove = signers[2];

        // Propose removing signer
        vm.prank(signers[0]);
        IMultisig(address(diamond)).removeSigner(signerToRemove);

        // Sign with other signers
        vm.prank(signers[1]);
        bytes32 txHash = keccak256(abi.encodePacked("removeSigner", signerToRemove));
        IMultisig(address(diamond)).signTransaction(txHash);

        vm.prank(signerToRemove); // Even the signer being removed can sign
        IMultisig(address(diamond)).signTransaction(txHash);
    }
}