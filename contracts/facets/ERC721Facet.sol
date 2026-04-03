// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC721} from "../interfaces/IERC721.sol";
import {LibAppStorage} from "../libraries/LibAppStorage.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";

contract ERC721Facet is IERC721 {

    // ERC721 interface id (EIP-165)
    bytes4 private constant _INTERFACE_ID_ERC721 = 0x80ac58cd;

    // modifier to guard token operations.
    modifier onlyApprovedOrOwner(uint256 tokenId) {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        require(LibAppStorage._isApprovedOrOwner(s, msg.sender, tokenId), "ERC721: caller is not token owner nor approved");
        _;
    }

    // ERC-165 support checker as required by standards.
    function supportsInterface(bytes4 interfaceId) external view returns (bool) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        if (interfaceId == _INTERFACE_ID_ERC721) {
            return true;
        }
        return ds.supportedInterfaces[interfaceId];
    }

    // Get ERC721 token collection name.
    function name() external view returns (string memory) {
        return LibAppStorage.appStorage().name;
    }

    // Get ERC721 token collection symbol.
    function symbol() external view returns (string memory) {
        return LibAppStorage.appStorage().symbol;
    }

    // Set token collection metadata (name and symbol).
    function setMetadata(string calldata _name, string calldata _symbol) external {
        // In a real setup, this should be protected by access control (owner only).
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        s.name = _name;
        s.symbol = _symbol;
    }

    // Return count of tokens held by owner.
    function balanceOf(address owner) external view override returns (uint256) {
        require(owner != address(0), "ERC721: balance query for the zero address");
        return LibAppStorage.appStorage().erc721Balances[owner];
    }

    // Return owner for tokenId.
    function ownerOf(uint256 tokenId) external view override returns (address) {
        address owner = LibAppStorage.appStorage().erc721OwnerOf[tokenId];
        require(owner != address(0), "ERC721: owner query for nonexistent token");
        return owner;
    }

    // Approve an address to transfer a specific token.
    function approve(address to, uint256 tokenId) external override {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        address owner = s.erc721OwnerOf[tokenId];
        require(owner != address(0), "ERC721: approve query for nonexistent token");
        require(to != owner, "ERC721: approval to current owner");
        require(msg.sender == owner || s.erc721OperatorApprovals[owner][msg.sender], "ERC721: approve caller is not owner nor approved for all");

        s.erc721Approvals[tokenId] = to;
        emit Approval(owner, to, tokenId);
    }

    // Get approved address for a token.
    function getApproved(uint256 tokenId) external view override returns (address) {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        require(LibAppStorage._exists(s, tokenId), "ERC721: approved query for nonexistent token");
        return s.erc721Approvals[tokenId];
    }

    // Set or clear operator approvals for all tokens of caller.
    function setApprovalForAll(address operator, bool approved) external override {
        require(operator != msg.sender, "ERC721: approve to caller");
        LibAppStorage.appStorage().erc721OperatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    ///  Returns if operator is approved to handle all tokens of owner.
    function isApprovedForAll(address owner, address operator) external view override returns (bool) {
        return LibAppStorage.appStorage().erc721OperatorApprovals[owner][operator];
    }

    ///  Transfer token from one address to another (no safe checks).
    function transferFrom(address from, address to, uint256 tokenId) public override {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        require(s.erc721OwnerOf[tokenId] == from, "ERC721: transfer of token that is not own");
        require(to != address(0), "ERC721: transfer to the zero address");
        require(msg.sender == from || s.erc721Approvals[tokenId] == msg.sender || s.erc721OperatorApprovals[from][msg.sender], "ERC721: caller is not owner nor approved");

        s.erc721Approvals[tokenId] = address(0);
        s.erc721Balances[from] -= 1;
        s.erc721Balances[to] += 1;
        s.erc721OwnerOf[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

    /// @notice 'Safe' transfer in this demo routes through transferFrom only.
    function safeTransferFrom(address from, address to, uint256 tokenId) external override {
        transferFrom(from, to, tokenId);
        // No IERC721Receiver check in example implementation.
    }

    /// @notice Mint a new token to an address.
    function mint(address to, uint256 tokenId) external {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        require(to != address(0), "ERC721: mint to the zero address");
        require(s.erc721OwnerOf[tokenId] == address(0), "ERC721: token already minted");

        s.erc721Balances[to] += 1;
        s.erc721OwnerOf[tokenId] = to;

        emit Transfer(address(0), to, tokenId);
    }
}

