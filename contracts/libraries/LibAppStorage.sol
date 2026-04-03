// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library LibAppStorage {


    struct AppStorage {
        // NFT collection name
        string name;
        // NFT symbol
        string symbol;

        // ERC721 mappings
        mapping(uint256 => address) erc721OwnerOf;
        mapping(address => uint256) erc721Balances;
        mapping(uint256 => address) erc721Approvals;
        mapping(address => mapping(address => bool)) erc721OperatorApprovals;

        // Additional ERC721 mappings for new facets
        mapping(uint256 => address) ownerOf;
        mapping(address => uint256) balanceOf;
        mapping(uint256 => address) tokenApprovals;
        mapping(address => mapping(address => bool)) operatorApprovals;

        // Staking: who staked which NFT and when
        mapping(uint256 => address) stakedBy;
        mapping(uint256 => uint256) stakedAt;
        mapping(address => uint256) stakerRewards;

        // Multisig: signers and pending transactions
        address[] multisigSigners;
        mapping(address => bool) isSigner;
        mapping(bytes32 => uint256) pendingTxApprovals; // txHash => approval count
        mapping(bytes32 => bool) executedTxs;

        // ERC20: balances and allowances
        mapping(address => uint256) erc20Balances;
        mapping(address => mapping(address => uint256)) erc20Allowances;
        uint256 erc20TotalSupply;

        // Borrower: who borrowed which NFT and expiry
        mapping(uint256 => address) borrowedBy;
        mapping(uint256 => uint256) loanExpiry;

        // Marketplace: listings (tokenId => price in ERC20)
        mapping(uint256 => uint256) listings;
    }

    /// Return the AppStorage struct pointer using a fixed storage slot.
    function appStorage() internal pure returns (AppStorage storage s) {
        // bytes32 position = 0;

        assembly {
            s.slot := 0
        }
    }



























    /// Check if a token exists (owner is not zero address).
    function _exists(AppStorage storage s, uint256 tokenId) internal view returns (bool) {
        return s.erc721OwnerOf[tokenId] != address(0);
    }

    ///  Check if a spender is token owner or approved operator.
    function _isApprovedOrOwner(AppStorage storage s, address spender, uint256 tokenId) internal view returns (bool) {
        address owner = s.erc721OwnerOf[tokenId];
        return (spender == owner || s.erc721Approvals[tokenId] == spender || s.erc721OperatorApprovals[owner][spender]);
    }

    ///  Return approved account for token.
    function getApproved(AppStorage storage s, uint256 tokenId) internal view returns (address) {
        require(_exists(s, tokenId), "ERC721: approved query for nonexistent token");
        return s.tokenApprovals[tokenId];
    }
}
