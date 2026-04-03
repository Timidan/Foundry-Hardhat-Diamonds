// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../libraries/LibAppStorage.sol";
import "../libraries/LibSVG.sol";

contract SVGFacet {

    /// @notice Generate on-chain SVG data URI for a token.
    function tokenURI(uint256 tokenId) external view returns (string memory) {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();

        // FIX: was s.ownerOf[tokenId] — always address(0).
        // ERC721Facet.mint() writes to s.erc721OwnerOf, so check that instead.
        require(s.erc721OwnerOf[tokenId] != address(0), "Token does not exist");

        string memory svg = LibSVG.generateSVG(tokenId, s.name, s.symbol);
        return string(abi.encodePacked("data:image/svg+xml;base64,", svg));
    }
}