// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LibAppStorage} from "../libraries/LibAppStorage.sol";

contract MintFacet {
    error MaxSupplyReached();
    error MintNotActive();
    error InsufficientPayment();
    error InvalidAddress();

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Minted(address indexed to, uint256 indexed tokenId);

    modifier nonReentrant() {
        LibAppStorage.NFTStorage storage s = LibAppStorage.nftStorage();
        require(
            s.reentrancyStatus != LibAppStorage._ENTERED,
            "ReentrancyGuard: reentrant call"
        );
        s.reentrancyStatus = LibAppStorage._ENTERED;
        _;
        s.reentrancyStatus = LibAppStorage._NOT_ENTERED;
    }

    function mint() external payable nonReentrant {
        LibAppStorage.NFTStorage storage s = LibAppStorage.nftStorage();

        if (!s.mintActive) revert MintNotActive();
        if (msg.value < s.mintPrice) revert InsufficientPayment();
        if (s.totalSupply >= s.maxSupply) revert MaxSupplyReached();

        uint256 tokenId = s.totalSupply + 1;

        s.totalSupply = tokenId;
        s.balances[msg.sender] += 1;
        s.owners[tokenId] = msg.sender;

        emit Minted(msg.sender, tokenId);
        emit Transfer(address(0), msg.sender, tokenId);
    }

    function mintTo(address to) external payable nonReentrant {
        if (to == address(0)) revert InvalidAddress();

        LibAppStorage.NFTStorage storage s = LibAppStorage.nftStorage();

        if (!s.mintActive) revert MintNotActive();
        if (msg.value < s.mintPrice) revert InsufficientPayment();
        if (s.totalSupply >= s.maxSupply) revert MaxSupplyReached();

        uint256 tokenId = s.totalSupply + 1;

        s.totalSupply = tokenId;
        s.balances[to] += 1;
        s.owners[tokenId] = to;

        emit Minted(to, tokenId);
        emit Transfer(address(0), to, tokenId);
    }

    function totalSupply() external view returns (uint256) {
        return LibAppStorage.nftStorage().totalSupply;
    }

    function mintPrice() external view returns (uint256) {
        return LibAppStorage.nftStorage().mintPrice;
    }

    function mintActive() external view returns (bool) {
        return LibAppStorage.nftStorage().mintActive;
    }

    function maxSupply() external view returns (uint256) {
        return LibAppStorage.nftStorage().maxSupply;
    }
}
