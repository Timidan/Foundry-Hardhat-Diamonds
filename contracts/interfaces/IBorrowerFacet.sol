// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBorrowerFacet {
    function borrowToken(uint256 tokenId, uint256 duration) external payable;
    function returnToken(uint256 tokenId) external;
    function getBorrowInfo(uint256 tokenId) external view returns (
        address borrower,
        uint256 deadline,
        uint256 fee,
        bool active
    );
    function isBorrowed(uint256 tokenId) external view returns (bool);
    function borrowFee() external view returns (uint256);
    function maxBorrowDuration() external view returns (uint256);
}
