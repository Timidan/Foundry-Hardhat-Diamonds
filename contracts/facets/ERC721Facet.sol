// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC721, IERC721Metadata, IERC721Receiver} from "../interfaces/IERC721.sol";
import {LibAppStorage} from "../libraries/LibAppStorage.sol";

contract ERC721Facet is IERC721, IERC721Metadata {
    error ERC721InvalidOwner(address owner);
    error ERC721NonexistentToken(uint256 tokenId);
    error ERC721IncorrectOwner(address sender, uint256 tokenId, address owner);
    error ERC721InvalidOperator(address operator);

    function balanceOf(address owner) external view returns (uint256) {
        if (owner == address(0)) revert ERC721InvalidOwner(address(0));
        return LibAppStorage.nftStorage().balances[owner];
    }

    function ownerOf(uint256 tokenId) public view returns (address) {
        address owner = LibAppStorage.nftStorage().owners[tokenId];
        if (owner == address(0)) revert ERC721NonexistentToken(tokenId);
        return owner;
    }

    function getApproved(uint256 tokenId) external view returns (address) {
        _requireTokenExists(tokenId);
        return LibAppStorage.nftStorage().tokenApprovals[tokenId];
    }

    function isApprovedForAll(address owner, address operator) external view returns (bool) {
        return LibAppStorage.nftStorage().operatorApprovals[owner][operator];
    }

    function approve(address to, uint256 tokenId) external {
        address owner = ownerOf(tokenId);
        if (to == owner) revert ERC721InvalidOperator(to);
        if (
            msg.sender != owner &&
            !LibAppStorage.nftStorage().operatorApprovals[owner][msg.sender]
        ) {
            revert ERC721InvalidOperator(msg.sender);
        }
        LibAppStorage.nftStorage().tokenApprovals[tokenId] = to;
        emit Approval(owner, to, tokenId);
    }

    function setApprovalForAll(address operator, bool approved) external {
        if (operator == msg.sender) revert ERC721InvalidOperator(operator);
        LibAppStorage.nftStorage().operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function transferFrom(address from, address to, uint256 tokenId) public {
        if (to == address(0)) revert ERC721InvalidOwner(address(0));
        address owner = ownerOf(tokenId);
        if (from != owner) revert ERC721IncorrectOwner(msg.sender, tokenId, owner);

        LibAppStorage.NFTStorage storage s = LibAppStorage.nftStorage();

        require(
            msg.sender == owner ||
            s.tokenApprovals[tokenId] == msg.sender ||
            s.operatorApprovals[owner][msg.sender],
            "ERC721: caller not token owner or approved"
        );

        delete s.tokenApprovals[tokenId];
        s.balances[from] -= 1;
        s.balances[to] += 1;
        s.owners[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public {
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public {
        transferFrom(from, to, tokenId);
        _checkOnERC721Received(from, to, tokenId, data);
    }

    function name() external view returns (string memory) {
        return LibAppStorage.nftStorage().name;
    }

    function symbol() external view returns (string memory) {
        return LibAppStorage.nftStorage().symbol;
    }

    function tokenURI(uint256 tokenId) external view returns (string memory) {
        _requireTokenExists(tokenId);
        LibAppStorage.NFTStorage storage s = LibAppStorage.nftStorage();
        string memory base = s.baseTokenURI;
        if (bytes(base).length == 0) return "";

        string memory _tokenId = _toString(tokenId);
        return string(abi.encodePacked(base, _tokenId));
    }

    function _requireTokenExists(uint256 tokenId) internal view {
        if (LibAppStorage.nftStorage().owners[tokenId] == address(0))
            revert ERC721NonexistentToken(tokenId);
    }

    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) internal {
        if (to.code.length > 0) {
            try
                IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, data)
            returns (bytes4 retval) {
                if (retval != IERC721Receiver.onERC721Received.selector) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                }
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        }
    }

    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}
