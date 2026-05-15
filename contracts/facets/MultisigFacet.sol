// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IMultisigFacet} from "../interfaces/IMultisigFacet.sol";
import {IDiamondCut} from "../interfaces/IDiamondCut.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {LibAppStorage} from "../libraries/LibAppStorage.sol";

contract MultisigFacet is IMultisigFacet {
    error NotMultisigOwner();
    error ProposalNotFound();
    error ProposalAlreadyExecuted();
    error ProposalCancelledError();
    error ProposalDeadlineExpired();
    error ProposalDeadlineNotExpired();
    error AlreadyVoted();
    error ThresholdNotMet();
    error InvalidThreshold();
    error CannotRemoveLastOwner();
    error NotProposer();
    error InvalidAddress();

    event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string description);
    event VoteCast(uint256 indexed proposalId, address indexed voter, bool support);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCancelled(uint256 indexed proposalId);
    event OwnerAdded(address indexed owner);
    event OwnerRemoved(address indexed owner);
    event ThresholdUpdated(uint256 oldThreshold, uint256 newThreshold);

    modifier onlyMultisigOwner() {
        if (!LibAppStorage.multisigStorage().isMultisigOwner[msg.sender])
            revert NotMultisigOwner();
        _;
    }

    function initializeMultisig(address[] calldata _owners, uint256 _threshold) external {
        LibDiamond.enforceIsContractOwner();
        LibAppStorage.MultisigStorage storage s = LibAppStorage.multisigStorage();

        if (_owners.length == 0) revert InvalidAddress();
        if (_threshold == 0 || _threshold > _owners.length) revert InvalidThreshold();

        for (uint256 i = 0; i < _owners.length; i++) {
            if (_owners[i] == address(0)) revert InvalidAddress();
            if (!s.isMultisigOwner[_owners[i]]) {
                s.multisigOwners.push(_owners[i]);
                s.isMultisigOwner[_owners[i]] = true;
            }
        }
        s.multisigThreshold = _threshold;
    }

    function createProposal(
        IDiamondCut.FacetCut[] calldata diamondCut,
        address init,
        bytes calldata initCalldata,
        string calldata description
    ) external onlyMultisigOwner returns (uint256) {
        LibAppStorage.MultisigStorage storage s = LibAppStorage.multisigStorage();

        s.multisigProposalCount++;
        uint256 proposalId = s.multisigProposalCount;

        _storeProposalCut(proposalId, diamondCut, init, initCalldata);

        s.proposals[proposalId] = LibAppStorage.MultisigProposal({
            proposer: msg.sender,
            votesFor: 0,
            votesAgainst: 0,
            deadline: block.timestamp + 7 days,
            executed: false,
            cancelled: false
        });

        emit ProposalCreated(proposalId, msg.sender, description);
        return proposalId;
    }

    function vote(uint256 proposalId, bool support) external onlyMultisigOwner {
        LibAppStorage.MultisigStorage storage s = LibAppStorage.multisigStorage();

        if (s.proposalVotes[proposalId][msg.sender]) revert AlreadyVoted();
        if (s.proposals[proposalId].executed) revert ProposalAlreadyExecuted();
        if (s.proposals[proposalId].cancelled) revert ProposalCancelledError();
        if (block.timestamp >= s.proposals[proposalId].deadline) revert ProposalDeadlineExpired();

        s.proposalVotes[proposalId][msg.sender] = true;

        if (support) {
            s.proposals[proposalId].votesFor++;
        } else {
            s.proposals[proposalId].votesAgainst++;
        }

        emit VoteCast(proposalId, msg.sender, support);
    }

    function executeProposal(uint256 proposalId) external {
        LibAppStorage.MultisigStorage storage s = LibAppStorage.multisigStorage();
        LibAppStorage.MultisigProposal storage proposal = s.proposals[proposalId];

        if (proposal.proposer == address(0)) revert ProposalNotFound();
        if (proposal.executed) revert ProposalAlreadyExecuted();
        if (proposal.cancelled) revert ProposalCancelledError();
        if (block.timestamp < proposal.deadline) revert ProposalDeadlineNotExpired();
        if (proposal.votesFor < s.multisigThreshold) revert ThresholdNotMet();

        proposal.executed = true;

        _executeProposalCut(proposalId);

        emit ProposalExecuted(proposalId);
    }

    function cancelProposal(uint256 proposalId) external {
        LibAppStorage.MultisigStorage storage s = LibAppStorage.multisigStorage();
        LibAppStorage.MultisigProposal storage proposal = s.proposals[proposalId];

        if (proposal.proposer == address(0)) revert ProposalNotFound();
        if (proposal.proposer != msg.sender) revert NotProposer();
        if (proposal.executed) revert ProposalAlreadyExecuted();

        proposal.cancelled = true;
        emit ProposalCancelled(proposalId);
    }

    function addOwner(address newOwner) external onlyMultisigOwner {
        if (newOwner == address(0)) revert InvalidAddress();
        LibAppStorage.MultisigStorage storage s = LibAppStorage.multisigStorage();

        if (!s.isMultisigOwner[newOwner]) {
            s.multisigOwners.push(newOwner);
            s.isMultisigOwner[newOwner] = true;
        }
        emit OwnerAdded(newOwner);
    }

    function removeOwner(address owner) external onlyMultisigOwner {
        LibAppStorage.MultisigStorage storage s = LibAppStorage.multisigStorage();

        if (s.multisigOwners.length <= s.multisigThreshold)
            revert CannotRemoveLastOwner();
        if (!s.isMultisigOwner[owner]) revert NotMultisigOwner();

        s.isMultisigOwner[owner] = false;

        for (uint256 i = 0; i < s.multisigOwners.length; i++) {
            if (s.multisigOwners[i] == owner) {
                s.multisigOwners[i] = s.multisigOwners[s.multisigOwners.length - 1];
                s.multisigOwners.pop();
                break;
            }
        }
        emit OwnerRemoved(owner);
    }

    function setThreshold(uint256 newThreshold) external onlyMultisigOwner {
        LibAppStorage.MultisigStorage storage s = LibAppStorage.multisigStorage();
        if (newThreshold == 0 || newThreshold > s.multisigOwners.length)
            revert InvalidThreshold();

        uint256 oldThreshold = s.multisigThreshold;
        s.multisigThreshold = newThreshold;
        emit ThresholdUpdated(oldThreshold, newThreshold);
    }

    function getProposal(uint256 proposalId) external view returns (IMultisigFacet.ProposalView memory) {
        LibAppStorage.MultisigProposal storage p = LibAppStorage.multisigStorage().proposals[proposalId];
        return IMultisigFacet.ProposalView({
            proposer: p.proposer,
            votesFor: p.votesFor,
            votesAgainst: p.votesAgainst,
            deadline: p.deadline,
            executed: p.executed,
            cancelled: p.cancelled
        });
    }

    function hasVoted(uint256 proposalId, address voter) external view returns (bool) {
        return LibAppStorage.multisigStorage().proposalVotes[proposalId][voter];
    }

    function isOwner(address account) external view returns (bool) {
        return LibAppStorage.multisigStorage().isMultisigOwner[account];
    }

    function getOwners() external view returns (address[] memory) {
        return LibAppStorage.multisigStorage().multisigOwners;
    }

    function threshold() external view returns (uint256) {
        return LibAppStorage.multisigStorage().multisigThreshold;
    }

    function proposalCount() external view returns (uint256) {
        return LibAppStorage.multisigStorage().multisigProposalCount;
    }

    struct ProposalCutData {
        address[] facetAddresses;
        bytes4[][] selectors;
        uint8[] actions;
        address init;
        bytes initCalldata;
    }

    mapping(uint256 => ProposalCutData) private proposalCutData;

    function _storeProposalCut(
        uint256 proposalId,
        IDiamondCut.FacetCut[] calldata diamondCut,
        address init,
        bytes calldata initCalldata
    ) internal {
        ProposalCutData storage cutData = proposalCutData[proposalId];
        cutData.init = init;
        cutData.initCalldata = initCalldata;

        for (uint256 i = 0; i < diamondCut.length; i++) {
            cutData.facetAddresses.push(diamondCut[i].facetAddress);
            cutData.actions.push(uint8(diamondCut[i].action));

            bytes4[] memory sels = diamondCut[i].functionSelectors;
            bytes4[] memory storedSels = new bytes4[](sels.length);
            for (uint256 j = 0; j < sels.length; j++) {
                storedSels[j] = sels[j];
            }
            cutData.selectors.push(storedSels);
        }
    }

    function _executeProposalCut(uint256 proposalId) internal {
        ProposalCutData storage cutData = proposalCutData[proposalId];

        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](cutData.facetAddresses.length);

        for (uint256 i = 0; i < cutData.facetAddresses.length; i++) {
            cut[i] = IDiamondCut.FacetCut({
                facetAddress: cutData.facetAddresses[i],
                action: IDiamondCut.FacetCutAction(cutData.actions[i]),
                functionSelectors: cutData.selectors[i]
            });
        }

        LibDiamond.diamondCut(cut, cutData.init, cutData.initCalldata);
    }
}
