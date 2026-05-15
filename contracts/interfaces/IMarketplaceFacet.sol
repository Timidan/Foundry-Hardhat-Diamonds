// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMarketplaceFacet {
    struct Listing {
        uint256 tokenId;
        address seller;
        uint256 price;
        bool active;
    }

    function listNFT(uint256 tokenId, uint256 price) external;
    function buyNFT(uint256 tokenId) external payable;
    function delistNFT(uint256 tokenId) external;
    function getListings() external view returns (Listing[] memory);
    function getListing(uint256 tokenId) external view returns (Listing memory);
    function isListed(uint256 tokenId) external view returns (bool);
    function marketplaceFee() external view returns (uint256);
}
