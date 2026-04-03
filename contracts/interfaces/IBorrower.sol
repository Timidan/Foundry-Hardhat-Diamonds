// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBorrower {
    function borrow(uint256 tokenId, uint256 duration) external;
    function returnBorrowed(uint256 tokenId) external;
    function getBorrowedBy(uint256 tokenId) external view returns (address);
}