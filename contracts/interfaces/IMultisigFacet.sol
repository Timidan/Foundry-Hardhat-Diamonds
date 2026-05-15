// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IDiamondCut} from "./IDiamondCut.sol";

interface IMultisigFacet {
    struct ProposalView {
        address proposer;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 deadline;
        bool executed;
        bool cancelled;
    }

    function createProposal(
        IDiamondCut.FacetCut[] calldata diamondCut,
        address init,
        bytes calldata initCalldata,
        string calldata description
    ) external returns (uint256);

    function vote(uint256 proposalId, bool support) external;
    function executeProposal(uint256 proposalId) external;
    function cancelProposal(uint256 proposalId) external;
    function addOwner(address newOwner) external;
    function removeOwner(address owner) external;
    function setThreshold(uint256 newThreshold) external;
    function getProposal(uint256 proposalId) external view returns (ProposalView memory);
    function hasVoted(uint256 proposalId, address voter) external view returns (bool);
    function isOwner(address account) external view returns (bool);
    function getOwners() external view returns (address[] memory);
    function threshold() external view returns (uint256);
    function proposalCount() external view returns (uint256);
}
