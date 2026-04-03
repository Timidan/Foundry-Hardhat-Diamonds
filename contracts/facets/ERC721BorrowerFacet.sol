// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IBorrower.sol";
import "../libraries/LibAppStorage.sol";

contract ERC721BorrowerFacet is IBorrower {

    /// @notice Borrow an NFT for a duration.
    function borrow(uint256 tokenId, uint256 duration) external {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();

        // FIX: was s.ownerOf[tokenId] — that mapping is never written to.
        // ERC721Facet.mint() writes to s.erc721OwnerOf, so we read from there.
        require(s.erc721OwnerOf[tokenId] != address(0), "Token does not exist");
        require(s.borrowedBy[tokenId] == address(0), "Already borrowed");

        s.borrowedBy[tokenId] = msg.sender;
        s.loanExpiry[tokenId] = block.timestamp + duration;
    }

    /// @notice Return a borrowed NFT.
    function returnBorrowed(uint256 tokenId) external {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        require(s.borrowedBy[tokenId] == msg.sender, "Not borrowed by you");

        delete s.borrowedBy[tokenId];
        delete s.loanExpiry[tokenId];
    }

    /// @notice Get who borrowed a token.
    function getBorrowedBy(uint256 tokenId) external view returns (address) {
        return LibAppStorage.appStorage().borrowedBy[tokenId];
    }
}