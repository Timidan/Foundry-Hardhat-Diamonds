// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/interfaces/IERC721.sol";
import "../contracts/interfaces/IERC165.sol";
import "../contracts/interfaces/IMultisigFacet.sol";
import "../contracts/libraries/LibDiamond.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "../contracts/facets/ERC721Facet.sol";
import "../contracts/facets/MintFacet.sol";
import "../contracts/facets/NFTAdminFacet.sol";
import "../contracts/facets/MultisigFacet.sol";
import "../contracts/Diamond.sol";
import "../contracts/upgradeInitializers/DiamondInit.sol";
import "../test/helpers/DiamondUpgradeHelper.sol";

contract MultisigFacetTest is Test, DiamondUpgradeHelper {
    Diamond diamond;
    ERC721Facet erc721;
    MintFacet mintFacet;
    NFTAdminFacet adminFacet;
    DiamondLoupeFacet loupe;
    MultisigFacet multisigFacet;

    address owner = address(this);
    address user1 = address(0xA11CE);
    address user2 = address(0xB0B);
    address user3 = address(0xC0D3);
    address user4 = address(0xD4D4);

    receive() external payable {}

    function setUp() public {
        DiamondCutFacet diamondCutFacet = new DiamondCutFacet();
        diamond = new Diamond(owner, address(diamondCutFacet));

        DiamondLoupeFacet diamondLoupeFacet = new DiamondLoupeFacet();
        OwnershipFacet ownershipFacet = new OwnershipFacet();
        ERC721Facet _erc721Facet = new ERC721Facet();
        MintFacet _mintFacet = new MintFacet();
        NFTAdminFacet _adminFacet = new NFTAdminFacet();
        MultisigFacet _multisigFacet = new MultisigFacet();

        DiamondInit diamondInit = new DiamondInit();

        address[] memory facetAddresses = new address[](6);
        facetAddresses[0] = address(diamondLoupeFacet);
        facetAddresses[1] = address(ownershipFacet);
        facetAddresses[2] = address(_erc721Facet);
        facetAddresses[3] = address(_mintFacet);
        facetAddresses[4] = address(_adminFacet);
        facetAddresses[5] = address(_multisigFacet);

        string[] memory facetNames = new string[](6);
        facetNames[0] = "DiamondLoupeFacet";
        facetNames[1] = "OwnershipFacet";
        facetNames[2] = "ERC721Facet";
        facetNames[3] = "MintFacet";
        facetNames[4] = "NFTAdminFacet";
        facetNames[5] = "MultisigFacet";

        IDiamondCut.FacetCut[] memory cuts = buildAddCutsByNames(
            facetAddresses,
            facetNames
        );

        bytes memory initCalldata = abi.encodeWithSelector(
            diamondInit.init.selector,
            DiamondInit.InitParams({
                name: "Diamond NFT",
                symbol: "DNFT",
                baseTokenURI: "https://api.example.com/metadata/",
                maxSupply: 100,
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

        executeDiamondCut(
            IDiamondCut(address(diamond)),
            cuts,
            address(diamondInit),
            initCalldata
        );

        erc721 = ERC721Facet(address(diamond));
        mintFacet = MintFacet(address(diamond));
        adminFacet = NFTAdminFacet(address(diamond));
        loupe = DiamondLoupeFacet(address(diamond));
        multisigFacet = MultisigFacet(address(diamond));

        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        vm.deal(user3, 100 ether);
        vm.deal(user4, 100 ether);
    }

    function test_initialize_multisig() public {
        address[] memory owners = new address[](3);
        owners[0] = user1;
        owners[1] = user2;
        owners[2] = user3;

        multisigFacet.initializeMultisig(owners, 2);

        assertEq(multisigFacet.threshold(), 2);
        assertTrue(multisigFacet.isOwner(user1));
        assertTrue(multisigFacet.isOwner(user2));
        assertTrue(multisigFacet.isOwner(user3));
        assertFalse(multisigFacet.isOwner(user4));
    }

    function test_initialize_multisig_owners_array() public {
        address[] memory owners = new address[](3);
        owners[0] = user1;
        owners[1] = user2;
        owners[2] = user3;

        multisigFacet.initializeMultisig(owners, 2);

        address[] memory returnedOwners = multisigFacet.getOwners();
        assertEq(returnedOwners.length, 3);
    }

    function test_initialize_duplicate_owners() public {
        address[] memory owners = new address[](4);
        owners[0] = user1;
        owners[1] = user1;
        owners[2] = user2;
        owners[3] = user3;

        multisigFacet.initializeMultisig(owners, 2);

        address[] memory returnedOwners = multisigFacet.getOwners();
        assertEq(returnedOwners.length, 3);
    }

    function test_initialize_empty_owners() public {
        address[] memory owners = new address[](0);
        vm.expectRevert();
        multisigFacet.initializeMultisig(owners, 1);
    }

    function test_initialize_invalid_threshold() public {
        address[] memory owners = new address[](2);
        owners[0] = user1;
        owners[1] = user2;

        vm.expectRevert();
        multisigFacet.initializeMultisig(owners, 0);
    }

    function test_initialize_threshold_too_high() public {
        address[] memory owners = new address[](2);
        owners[0] = user1;
        owners[1] = user2;

        vm.expectRevert();
        multisigFacet.initializeMultisig(owners, 5);
    }

    function test_create_proposal() public {
        address[] memory owners = new address[](3);
        owners[0] = user1;
        owners[1] = user2;
        owners[2] = user3;
        multisigFacet.initializeMultisig(owners, 2);

        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](0);

        vm.prank(user1);
        uint256 proposalId = multisigFacet.createProposal(cut, address(0), "", "Test proposal");

        assertEq(multisigFacet.proposalCount(), 1);
        assertEq(proposalId, 1);
    }

    function test_create_proposal_emits_event() public {
        address[] memory owners = new address[](3);
        owners[0] = user1;
        owners[1] = user2;
        owners[2] = user3;
        multisigFacet.initializeMultisig(owners, 2);

        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](0);

        vm.prank(user1);
        vm.expectEmit(true, true, false, true);
        emit MultisigFacet.ProposalCreated(1, user1, "Test proposal");
        multisigFacet.createProposal(cut, address(0), "", "Test proposal");
    }

    function test_create_proposal_non_owner() public {
        address[] memory owners = new address[](3);
        owners[0] = user1;
        owners[1] = user2;
        owners[2] = user3;
        multisigFacet.initializeMultisig(owners, 2);

        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](0);

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSignature("NotMultisigOwner()")
        );
        multisigFacet.createProposal(cut, address(0), "", "Test");
    }

    function test_vote_for_proposal() public {
        address[] memory owners = new address[](3);
        owners[0] = user1;
        owners[1] = user2;
        owners[2] = user3;
        multisigFacet.initializeMultisig(owners, 2);

        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](0);

        vm.prank(user1);
        uint256 proposalId = multisigFacet.createProposal(cut, address(0), "", "Test proposal");

        vm.prank(user1);
        multisigFacet.vote(proposalId, true);

        IMultisigFacet.ProposalView memory proposal = multisigFacet.getProposal(proposalId);
        assertEq(proposal.votesFor, 1);
        assertEq(proposal.votesAgainst, 0);
    }

    function test_vote_against_proposal() public {
        address[] memory owners = new address[](3);
        owners[0] = user1;
        owners[1] = user2;
        owners[2] = user3;
        multisigFacet.initializeMultisig(owners, 2);

        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](0);

        vm.prank(user1);
        uint256 proposalId = multisigFacet.createProposal(cut, address(0), "", "Test proposal");

        vm.prank(user1);
        multisigFacet.vote(proposalId, false);

        IMultisigFacet.ProposalView memory proposal = multisigFacet.getProposal(proposalId);
        assertEq(proposal.votesFor, 0);
        assertEq(proposal.votesAgainst, 1);
    }

    function test_vote_emits_event() public {
        address[] memory owners = new address[](3);
        owners[0] = user1;
        owners[1] = user2;
        owners[2] = user3;
        multisigFacet.initializeMultisig(owners, 2);

        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](0);

        vm.prank(user1);
        uint256 proposalId = multisigFacet.createProposal(cut, address(0), "", "Test");

        vm.prank(user1);
        vm.expectEmit(true, true, false, true);
        emit MultisigFacet.VoteCast(proposalId, user1, true);
        multisigFacet.vote(proposalId, true);
    }

    function test_double_vote_reverts() public {
        address[] memory owners = new address[](3);
        owners[0] = user1;
        owners[1] = user2;
        owners[2] = user3;
        multisigFacet.initializeMultisig(owners, 2);

        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](0);

        vm.prank(user1);
        uint256 proposalId = multisigFacet.createProposal(cut, address(0), "", "Test");

        vm.prank(user1);
        multisigFacet.vote(proposalId, true);

        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSignature("AlreadyVoted()")
        );
        multisigFacet.vote(proposalId, true);
    }

    function test_non_owner_cannot_vote() public {
        address[] memory owners = new address[](3);
        owners[0] = user1;
        owners[1] = user2;
        owners[2] = user3;
        multisigFacet.initializeMultisig(owners, 2);

        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](0);

        vm.prank(user1);
        uint256 proposalId = multisigFacet.createProposal(cut, address(0), "", "Test");

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSignature("NotMultisigOwner()")
        );
        multisigFacet.vote(proposalId, true);
    }

    function test_has_voted() public {
        address[] memory owners = new address[](3);
        owners[0] = user1;
        owners[1] = user2;
        owners[2] = user3;
        multisigFacet.initializeMultisig(owners, 2);

        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](0);

        vm.prank(user1);
        uint256 proposalId = multisigFacet.createProposal(cut, address(0), "", "Test");

        assertFalse(multisigFacet.hasVoted(proposalId, user1));

        vm.prank(user1);
        multisigFacet.vote(proposalId, true);

        assertTrue(multisigFacet.hasVoted(proposalId, user1));
        assertFalse(multisigFacet.hasVoted(proposalId, user2));
    }

    function test_execute_proposal() public {
        address[] memory owners = new address[](3);
        owners[0] = user1;
        owners[1] = user2;
        owners[2] = user3;
        multisigFacet.initializeMultisig(owners, 2);

        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](0);

        vm.prank(user1);
        uint256 proposalId = multisigFacet.createProposal(cut, address(0), "", "Test proposal");

        vm.prank(user1);
        multisigFacet.vote(proposalId, true);

        vm.prank(user2);
        multisigFacet.vote(proposalId, true);

        vm.warp(block.timestamp + 8 days);

        multisigFacet.executeProposal(proposalId);

        IMultisigFacet.ProposalView memory proposal = multisigFacet.getProposal(proposalId);
        assertTrue(proposal.executed);
    }

    function test_execute_proposal_emits_event() public {
        address[] memory owners = new address[](3);
        owners[0] = user1;
        owners[1] = user2;
        owners[2] = user3;
        multisigFacet.initializeMultisig(owners, 2);

        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](0);

        vm.prank(user1);
        uint256 proposalId = multisigFacet.createProposal(cut, address(0), "", "Test");

        vm.prank(user1);
        multisigFacet.vote(proposalId, true);

        vm.prank(user2);
        multisigFacet.vote(proposalId, true);

        vm.warp(block.timestamp + 8 days);

        vm.expectEmit(true, false, false, true);
        emit MultisigFacet.ProposalExecuted(proposalId);
        multisigFacet.executeProposal(proposalId);
    }

    function test_execute_before_deadline() public {
        address[] memory owners = new address[](3);
        owners[0] = user1;
        owners[1] = user2;
        owners[2] = user3;
        multisigFacet.initializeMultisig(owners, 2);

        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](0);

        vm.prank(user1);
        uint256 proposalId = multisigFacet.createProposal(cut, address(0), "", "Test");

        vm.prank(user1);
        multisigFacet.vote(proposalId, true);

        vm.prank(user2);
        multisigFacet.vote(proposalId, true);

        vm.expectRevert(
            abi.encodeWithSignature("ProposalDeadlineNotExpired()")
        );
        multisigFacet.executeProposal(proposalId);
    }

    function test_execute_threshold_not_met() public {
        address[] memory owners = new address[](3);
        owners[0] = user1;
        owners[1] = user2;
        owners[2] = user3;
        multisigFacet.initializeMultisig(owners, 2);

        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](0);

        vm.prank(user1);
        uint256 proposalId = multisigFacet.createProposal(cut, address(0), "", "Test");

        vm.prank(user1);
        multisigFacet.vote(proposalId, true);

        vm.warp(block.timestamp + 8 days);

        vm.expectRevert(
            abi.encodeWithSignature("ThresholdNotMet()")
        );
        multisigFacet.executeProposal(proposalId);
    }

    function test_execute_already_executed() public {
        address[] memory owners = new address[](3);
        owners[0] = user1;
        owners[1] = user2;
        owners[2] = user3;
        multisigFacet.initializeMultisig(owners, 2);

        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](0);

        vm.prank(user1);
        uint256 proposalId = multisigFacet.createProposal(cut, address(0), "", "Test");

        vm.prank(user1);
        multisigFacet.vote(proposalId, true);

        vm.prank(user2);
        multisigFacet.vote(proposalId, true);

        vm.warp(block.timestamp + 8 days);

        multisigFacet.executeProposal(proposalId);

        vm.expectRevert(
            abi.encodeWithSignature("ProposalAlreadyExecuted()")
        );
        multisigFacet.executeProposal(proposalId);
    }

    function test_cancel_proposal() public {
        address[] memory owners = new address[](3);
        owners[0] = user1;
        owners[1] = user2;
        owners[2] = user3;
        multisigFacet.initializeMultisig(owners, 2);

        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](0);

        vm.prank(user1);
        uint256 proposalId = multisigFacet.createProposal(cut, address(0), "", "Test");

        vm.prank(user1);
        multisigFacet.cancelProposal(proposalId);

        IMultisigFacet.ProposalView memory proposal = multisigFacet.getProposal(proposalId);
        assertTrue(proposal.cancelled);
    }

    function test_cancel_proposal_emits_event() public {
        address[] memory owners = new address[](3);
        owners[0] = user1;
        owners[1] = user2;
        owners[2] = user3;
        multisigFacet.initializeMultisig(owners, 2);

        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](0);

        vm.prank(user1);
        uint256 proposalId = multisigFacet.createProposal(cut, address(0), "", "Test");

        vm.prank(user1);
        vm.expectEmit(true, false, false, true);
        emit MultisigFacet.ProposalCancelled(proposalId);
        multisigFacet.cancelProposal(proposalId);
    }

    function test_cancel_non_proposer() public {
        address[] memory owners = new address[](3);
        owners[0] = user1;
        owners[1] = user2;
        owners[2] = user3;
        multisigFacet.initializeMultisig(owners, 2);

        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](0);

        vm.prank(user1);
        uint256 proposalId = multisigFacet.createProposal(cut, address(0), "", "Test");

        vm.prank(user2);
        vm.expectRevert(
            abi.encodeWithSignature("NotProposer()")
        );
        multisigFacet.cancelProposal(proposalId);
    }

    function test_add_owner() public {
        address[] memory owners = new address[](2);
        owners[0] = user1;
        owners[1] = user2;
        multisigFacet.initializeMultisig(owners, 1);

        vm.prank(user1);
        multisigFacet.addOwner(user3);

        assertTrue(multisigFacet.isOwner(user3));
    }

    function test_add_owner_emits_event() public {
        address[] memory owners = new address[](2);
        owners[0] = user1;
        owners[1] = user2;
        multisigFacet.initializeMultisig(owners, 1);

        vm.prank(user1);
        vm.expectEmit(true, false, false, true);
        emit MultisigFacet.OwnerAdded(user3);
        multisigFacet.addOwner(user3);
    }

    function test_remove_owner() public {
        address[] memory owners = new address[](3);
        owners[0] = user1;
        owners[1] = user2;
        owners[2] = user3;
        multisigFacet.initializeMultisig(owners, 1);

        vm.prank(user1);
        multisigFacet.removeOwner(user3);

        assertFalse(multisigFacet.isOwner(user3));
    }

    function test_remove_owner_emits_event() public {
        address[] memory owners = new address[](3);
        owners[0] = user1;
        owners[1] = user2;
        owners[2] = user3;
        multisigFacet.initializeMultisig(owners, 1);

        vm.prank(user1);
        vm.expectEmit(true, false, false, true);
        emit MultisigFacet.OwnerRemoved(user3);
        multisigFacet.removeOwner(user3);
    }

    function test_remove_last_owner_reverts() public {
        address[] memory owners = new address[](2);
        owners[0] = user1;
        owners[1] = user2;
        multisigFacet.initializeMultisig(owners, 2);

        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSignature("CannotRemoveLastOwner()")
        );
        multisigFacet.removeOwner(user2);
    }

    function test_set_threshold() public {
        address[] memory owners = new address[](3);
        owners[0] = user1;
        owners[1] = user2;
        owners[2] = user3;
        multisigFacet.initializeMultisig(owners, 1);

        vm.prank(user1);
        multisigFacet.setThreshold(2);

        assertEq(multisigFacet.threshold(), 2);
    }

    function test_set_threshold_emits_event() public {
        address[] memory owners = new address[](3);
        owners[0] = user1;
        owners[1] = user2;
        owners[2] = user3;
        multisigFacet.initializeMultisig(owners, 1);

        vm.prank(user1);
        vm.expectEmit(false, false, false, true);
        emit MultisigFacet.ThresholdUpdated(1, 2);
        multisigFacet.setThreshold(2);
    }

    function test_set_threshold_invalid() public {
        address[] memory owners = new address[](3);
        owners[0] = user1;
        owners[1] = user2;
        owners[2] = user3;
        multisigFacet.initializeMultisig(owners, 1);

        vm.prank(user1);
        vm.expectRevert();
        multisigFacet.setThreshold(0);
    }

    function test_vote_after_deadline() public {
        address[] memory owners = new address[](3);
        owners[0] = user1;
        owners[1] = user2;
        owners[2] = user3;
        multisigFacet.initializeMultisig(owners, 2);

        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](0);

        vm.prank(user1);
        uint256 proposalId = multisigFacet.createProposal(cut, address(0), "", "Test");

        vm.warp(block.timestamp + 8 days);

        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSignature("ProposalDeadlineExpired()")
        );
        multisigFacet.vote(proposalId, true);
    }

    function test_cancel_already_executed() public {
        address[] memory owners = new address[](3);
        owners[0] = user1;
        owners[1] = user2;
        owners[2] = user3;
        multisigFacet.initializeMultisig(owners, 2);

        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](0);

        vm.prank(user1);
        uint256 proposalId = multisigFacet.createProposal(cut, address(0), "", "Test");

        vm.prank(user1);
        multisigFacet.vote(proposalId, true);

        vm.prank(user2);
        multisigFacet.vote(proposalId, true);

        vm.warp(block.timestamp + 8 days);

        multisigFacet.executeProposal(proposalId);

        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSignature("ProposalAlreadyExecuted()")
        );
        multisigFacet.cancelProposal(proposalId);
    }

    function test_execute_cancelled_proposal() public {
        address[] memory owners = new address[](3);
        owners[0] = user1;
        owners[1] = user2;
        owners[2] = user3;
        multisigFacet.initializeMultisig(owners, 2);

        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](0);

        vm.prank(user1);
        uint256 proposalId = multisigFacet.createProposal(cut, address(0), "", "Test");

        vm.prank(user1);
        multisigFacet.cancelProposal(proposalId);

        vm.warp(block.timestamp + 8 days);

        vm.expectRevert(
            abi.encodeWithSignature("ProposalCancelledError()")
        );
        multisigFacet.executeProposal(proposalId);
    }
}
