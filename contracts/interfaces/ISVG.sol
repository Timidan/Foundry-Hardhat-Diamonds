// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/// @title SVG Facet Interface
/// @notice Interface for generating on-chain SVG token URIs
interface ISVG {
    /// @notice Get the token URI for an NFT, including SVG image data
    /// @param tokenId The token ID to get the URI for
    /// @return The token URI as a data URI with base64 encoded JSON
    function tokenURI(uint256 tokenId) external view returns (string memory);
}