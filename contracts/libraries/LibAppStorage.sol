// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library LibAppStorage {
    uint256 constant _NOT_ENTERED = 1;
    uint256 constant _ENTERED = 2;

    bytes32 constant NFT_STORAGE_POSITION = keccak256("nft.diamond.storage");
    bytes32 constant ERC20_STORAGE_POSITION = keccak256("erc20.diamond.storage");
    bytes32 constant STAKING_STORAGE_POSITION = keccak256("staking.diamond.storage");
    bytes32 constant BORROW_STORAGE_POSITION = keccak256("borrow.diamond.storage");
    bytes32 constant MARKETPLACE_STORAGE_POSITION = keccak256("marketplace.diamond.storage");
    bytes32 constant SVG_STORAGE_POSITION = keccak256("svg.diamond.storage");
    bytes32 constant MULTISIG_STORAGE_POSITION = keccak256("multisig.diamond.storage");

    // ==================== NFT Storage ====================

    struct NFTStorage {
        mapping(address => uint256) balances;
        mapping(uint256 => address) owners;
        mapping(uint256 => address) tokenApprovals;
        mapping(address => mapping(address => bool)) operatorApprovals;
        string name;
        string symbol;
        string baseTokenURI;
        uint256 totalSupply;
        uint256 maxSupply;
        uint256 mintPrice;
        bool mintActive;
        uint256 reentrancyStatus;
    }

    function nftStorage() internal pure returns (NFTStorage storage s) {
        bytes32 position = NFT_STORAGE_POSITION;
        assembly { s.slot := position }
    }

    // ==================== ERC-20 Storage ====================

    struct ERC20Storage {
        string erc20Name;
        string erc20Symbol;
        uint8 erc20Decimals;
        uint256 erc20TotalSupply;
        uint256 erc20MaxSupply;
        mapping(address => uint256) erc20Balances;
        mapping(address => mapping(address => uint256)) erc20Allowances;
    }

    function erc20Storage() internal pure returns (ERC20Storage storage s) {
        bytes32 position = ERC20_STORAGE_POSITION;
        assembly { s.slot := position }
    }

    // ==================== Staking Storage ====================

    struct StakeInfo {
        address staker;
        uint256 timestamp;
        uint256 reward;
    }

    struct StakingStorage {
        mapping(uint256 => StakeInfo) stakes;
        uint256 totalStaked;
        uint256 rewardRate;
        uint256 minStakeDuration;
    }

    function stakingStorage() internal pure returns (StakingStorage storage s) {
        bytes32 position = STAKING_STORAGE_POSITION;
        assembly { s.slot := position }
    }

    // ==================== Borrow Storage ====================

    struct BorrowInfoStruct {
        address borrower;
        uint256 deadline;
        uint256 fee;
        bool active;
    }

    struct BorrowStorage {
        mapping(uint256 => BorrowInfoStruct) borrows;
        mapping(uint256 => address) originalOwners;
        uint256 borrowFee;
        uint256 maxBorrowDuration;
    }

    function borrowStorage() internal pure returns (BorrowStorage storage s) {
        bytes32 position = BORROW_STORAGE_POSITION;
        assembly { s.slot := position }
    }

    // ==================== Marketplace Storage ====================

    struct MarketplaceListing {
        uint256 tokenId;
        address seller;
        uint256 price;
        bool active;
    }

    struct MarketplaceStorage {
        mapping(uint256 => MarketplaceListing) listings;
        uint256[] listingTokenIds;
        uint256 marketplaceFee;
    }

    function marketplaceStorage() internal pure returns (MarketplaceStorage storage s) {
        bytes32 position = MARKETPLACE_STORAGE_POSITION;
        assembly { s.slot := position }
    }

    // ==================== SVG Storage ====================

    struct SVGStorage {
        mapping(uint256 => string) tokenShapes;
        mapping(uint256 => string) tokenPrimaryColors;
        mapping(uint256 => string) tokenSecondaryColors;
    }

    function svgStorage() internal pure returns (SVGStorage storage s) {
        bytes32 position = SVG_STORAGE_POSITION;
        assembly { s.slot := position }
    }

    // ==================== Multisig Storage ====================

    struct MultisigProposal {
        address proposer;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 deadline;
        bool executed;
        bool cancelled;
    }

    struct MultisigStorage {
        address[] multisigOwners;
        mapping(address => bool) isMultisigOwner;
        mapping(uint256 => MultisigProposal) proposals;
        mapping(uint256 => mapping(address => bool)) proposalVotes;
        uint256 multisigProposalCount;
        uint256 multisigThreshold;
    }

    function multisigStorage() internal pure returns (MultisigStorage storage s) {
        bytes32 position = MULTISIG_STORAGE_POSITION;
        assembly { s.slot := position }
    }

    // ==================== Reentrancy Modifier ====================

    modifier nonReentrant() {
        NFTStorage storage s = nftStorage();
        require(s.reentrancyStatus != _ENTERED, "ReentrancyGuard: reentrant call");
        s.reentrancyStatus = _ENTERED;
        _;
        s.reentrancyStatus = _NOT_ENTERED;
    }
}
