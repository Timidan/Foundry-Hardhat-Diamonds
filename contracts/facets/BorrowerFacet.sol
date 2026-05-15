// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IBorrowerFacet} from "../interfaces/IBorrowerFacet.sol";
import {IERC721} from "../interfaces/IERC721.sol";
import {LibAppStorage} from "../libraries/LibAppStorage.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";

contract BorrowerFacet is IBorrowerFacet {
    error TokenNotOwned(uint256 tokenId);
    error TokenAlreadyBorrowed(uint256 tokenId);
    error TokenNotBorrowed(uint256 tokenId);
    error BorrowNotExpired(uint256 tokenId);
    error DurationTooLong(uint256 duration);
    error InsufficientFee(uint256 sent, uint256 required);
    error Unauthorized();

    event TokenBorrowed(address indexed borrower, uint256 indexed tokenId, uint256 duration, uint256 fee, uint256 deadline);
    event TokenReturned(address indexed borrower, uint256 indexed tokenId);
    event BorrowFeeUpdated(uint256 oldFee, uint256 newFee);
    event MaxBorrowDurationUpdated(uint256 oldDuration, uint256 newDuration);

    function borrowToken(uint256 tokenId, uint256 duration) external payable {
        LibAppStorage.NFTStorage storage nft = LibAppStorage.nftStorage();
        LibAppStorage.BorrowStorage storage brw = LibAppStorage.borrowStorage();

        if (nft.owners[tokenId] == address(0)) revert TokenNotOwned(tokenId);
        if (nft.owners[tokenId] == msg.sender) revert TokenNotOwned(tokenId);
        if (brw.borrows[tokenId].active) revert TokenAlreadyBorrowed(tokenId);
        if (duration > brw.maxBorrowDuration) revert DurationTooLong(duration);

        uint256 fee = brw.borrowFee;
        if (msg.value < fee) revert InsufficientFee(msg.value, fee);

        address originalOwner = nft.owners[tokenId];
        brw.originalOwners[tokenId] = originalOwner;

        nft.balances[originalOwner] -= 1;
        nft.balances[msg.sender] += 1;
        nft.owners[tokenId] = msg.sender;

        brw.borrows[tokenId] = LibAppStorage.BorrowInfoStruct({
            borrower: msg.sender,
            deadline: block.timestamp + duration,
            fee: fee,
            active: true
        });

        emit TokenBorrowed(msg.sender, tokenId, duration, fee, block.timestamp + duration);
    }

    function returnToken(uint256 tokenId) external {
        LibAppStorage.NFTStorage storage nft = LibAppStorage.nftStorage();
        LibAppStorage.BorrowStorage storage brw = LibAppStorage.borrowStorage();
        LibAppStorage.BorrowInfoStruct storage borrow = brw.borrows[tokenId];

        if (!borrow.active) revert TokenNotBorrowed(tokenId);
        if (borrow.borrower != msg.sender) revert Unauthorized();
        if (block.timestamp < borrow.deadline) revert BorrowNotExpired(tokenId);

        address originalOwner = brw.originalOwners[tokenId];

        nft.balances[msg.sender] -= 1;
        nft.balances[originalOwner] += 1;
        nft.owners[tokenId] = originalOwner;

        delete brw.borrows[tokenId];
        delete brw.originalOwners[tokenId];

        emit TokenReturned(msg.sender, tokenId);
    }

    function getBorrowInfo(uint256 tokenId) external view returns (
        address borrower,
        uint256 deadline,
        uint256 fee,
        bool active
    ) {
        LibAppStorage.BorrowInfoStruct storage b = LibAppStorage.borrowStorage().borrows[tokenId];
        return (b.borrower, b.deadline, b.fee, b.active);
    }

    function isBorrowed(uint256 tokenId) external view returns (bool) {
        return LibAppStorage.borrowStorage().borrows[tokenId].active;
    }

    function borrowFee() external view returns (uint256) {
        return LibAppStorage.borrowStorage().borrowFee;
    }

    function maxBorrowDuration() external view returns (uint256) {
        return LibAppStorage.borrowStorage().maxBorrowDuration;
    }

    function setBorrowFee(uint256 _fee) external {
        LibDiamond.enforceIsContractOwner();
        uint256 oldFee = LibAppStorage.borrowStorage().borrowFee;
        LibAppStorage.borrowStorage().borrowFee = _fee;
        emit BorrowFeeUpdated(oldFee, _fee);
    }

    function setMaxBorrowDuration(uint256 _duration) external {
        LibDiamond.enforceIsContractOwner();
        uint256 oldDuration = LibAppStorage.borrowStorage().maxBorrowDuration;
        LibAppStorage.borrowStorage().maxBorrowDuration = _duration;
        emit MaxBorrowDurationUpdated(oldDuration, _duration);
    }
}
