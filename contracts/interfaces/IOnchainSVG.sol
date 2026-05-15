// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IOnchainSVG {
    function generateSVG(uint256 tokenId) external view returns (string memory);
    function getTokenSVG(uint256 tokenId) external view returns (string memory);
    function setTokenShape(uint256 tokenId, string calldata shape) external;
    function setTokenColors(uint256 tokenId, string calldata primary, string calldata secondary) external;
    function tokenShape(uint256 tokenId) external view returns (string memory);
    function tokenColors(uint256 tokenId) external view returns (string memory primary, string memory secondary);
}
