// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMarketplace {
    function list(uint256 tokenId, uint256 price) external;
    function buy(uint256 tokenId) external;
    function getListing(uint256 tokenId) external view returns (uint256);
}