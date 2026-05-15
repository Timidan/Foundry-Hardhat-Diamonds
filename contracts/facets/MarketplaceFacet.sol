// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IMarketplaceFacet} from "../interfaces/IMarketplaceFacet.sol";
import {IERC721} from "../interfaces/IERC721.sol";
import {IERC20} from "../interfaces/IERC20.sol";
import {LibAppStorage} from "../libraries/LibAppStorage.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";

contract MarketplaceFacet is IMarketplaceFacet {
    error TokenNotOwned(uint256 tokenId);
    error TokenAlreadyListed(uint256 tokenId);
    error TokenNotListed(uint256 tokenId);
    error ListingNotActive(uint256 tokenId);
    error InsufficientPayment(uint256 sent, uint256 required);
    error Unauthorized();
    error InvalidPrice();
    error InvalidFee();

    event NFTListed(uint256 indexed tokenId, address indexed seller, uint256 price);
    event NFTSold(uint256 indexed tokenId, address indexed seller, address indexed buyer, uint256 price);
    event NFTDelisted(uint256 indexed tokenId, address indexed seller);
    event MarketplaceFeeUpdated(uint256 oldFee, uint256 newFee);

    function listNFT(uint256 tokenId, uint256 price) external {
        LibAppStorage.NFTStorage storage nft = LibAppStorage.nftStorage();
        LibAppStorage.MarketplaceStorage storage mkt = LibAppStorage.marketplaceStorage();

        if (mkt.listings[tokenId].active) revert TokenAlreadyListed(tokenId);
        if (nft.owners[tokenId] != msg.sender) revert TokenNotOwned(tokenId);
        if (price == 0) revert InvalidPrice();

        nft.balances[msg.sender] -= 1;
        nft.owners[tokenId] = address(this);

        mkt.listings[tokenId] = LibAppStorage.MarketplaceListing({
            tokenId: tokenId,
            seller: msg.sender,
            price: price,
            active: true
        });
        mkt.listingTokenIds.push(tokenId);

        emit NFTListed(tokenId, msg.sender, price);
    }

    function buyNFT(uint256 tokenId) external payable {
        LibAppStorage.NFTStorage storage nft = LibAppStorage.nftStorage();
        LibAppStorage.MarketplaceStorage storage mkt = LibAppStorage.marketplaceStorage();
        LibAppStorage.ERC20Storage storage erc20 = LibAppStorage.erc20Storage();
        LibAppStorage.MarketplaceListing storage listing = mkt.listings[tokenId];

        if (!listing.active) revert ListingNotActive(tokenId);
        if (listing.tokenId != tokenId) revert TokenNotListed(tokenId);

        uint256 price = listing.price;
        if (msg.value < price) revert InsufficientPayment(msg.value, price);

        address seller = listing.seller;
        uint256 feeAmount = (price * mkt.marketplaceFee) / 10000;
        uint256 sellerAmount = price - feeAmount;

        if (erc20.erc20Balances[msg.sender] < price)
            revert InsufficientPayment(msg.value, price);

        erc20.erc20Balances[msg.sender] -= price;
        erc20.erc20Balances[seller] += sellerAmount;

        address diamondOwner = LibDiamond.contractOwner();
        erc20.erc20Balances[diamondOwner] += feeAmount;

        nft.balances[msg.sender] += 1;
        nft.owners[tokenId] = msg.sender;

        listing.active = false;
        _removeListingTokenId(tokenId);

        emit NFTSold(tokenId, seller, msg.sender, price);
    }

    function delistNFT(uint256 tokenId) external {
        LibAppStorage.NFTStorage storage nft = LibAppStorage.nftStorage();
        LibAppStorage.MarketplaceStorage storage mkt = LibAppStorage.marketplaceStorage();
        LibAppStorage.MarketplaceListing storage listing = mkt.listings[tokenId];

        if (!listing.active) revert ListingNotActive(tokenId);
        if (listing.seller != msg.sender) revert Unauthorized();

        nft.balances[msg.sender] += 1;
        nft.owners[tokenId] = msg.sender;

        listing.active = false;
        _removeListingTokenId(tokenId);

        emit NFTDelisted(tokenId, msg.sender);
    }

    function getListings() external view returns (IMarketplaceFacet.Listing[] memory) {
        LibAppStorage.MarketplaceStorage storage mkt = LibAppStorage.marketplaceStorage();
        uint256 count = mkt.listingTokenIds.length;
        IMarketplaceFacet.Listing[] memory activeListings = new IMarketplaceFacet.Listing[](count);
        uint256 activeCount;

        for (uint256 i = 0; i < count; i++) {
            uint256 tokenId = mkt.listingTokenIds[i];
            if (mkt.listings[tokenId].active) {
                LibAppStorage.MarketplaceListing storage l = mkt.listings[tokenId];
                activeListings[activeCount] = IMarketplaceFacet.Listing({
                    tokenId: l.tokenId,
                    seller: l.seller,
                    price: l.price,
                    active: l.active
                });
                activeCount++;
            }
        }

        assembly {
            mstore(activeListings, activeCount)
        }

        return activeListings;
    }

    function getListing(uint256 tokenId) external view returns (IMarketplaceFacet.Listing memory) {
        LibAppStorage.MarketplaceListing storage l = LibAppStorage.marketplaceStorage().listings[tokenId];
        return IMarketplaceFacet.Listing({
            tokenId: l.tokenId,
            seller: l.seller,
            price: l.price,
            active: l.active
        });
    }

    function isListed(uint256 tokenId) external view returns (bool) {
        return LibAppStorage.marketplaceStorage().listings[tokenId].active;
    }

    function marketplaceFee() external view returns (uint256) {
        return LibAppStorage.marketplaceStorage().marketplaceFee;
    }

    function setMarketplaceFee(uint256 _fee) external {
        LibDiamond.enforceIsContractOwner();
        if (_fee > 1000) revert InvalidFee();
        uint256 oldFee = LibAppStorage.marketplaceStorage().marketplaceFee;
        LibAppStorage.marketplaceStorage().marketplaceFee = _fee;
        emit MarketplaceFeeUpdated(oldFee, _fee);
    }

    function _removeListingTokenId(uint256 tokenId) internal {
        LibAppStorage.MarketplaceStorage storage mkt = LibAppStorage.marketplaceStorage();
        for (uint256 i = 0; i < mkt.listingTokenIds.length; i++) {
            if (mkt.listingTokenIds[i] == tokenId) {
                mkt.listingTokenIds[i] = mkt.listingTokenIds[mkt.listingTokenIds.length - 1];
                mkt.listingTokenIds.pop();
                break;
            }
        }
    }
}
