// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IMarketplace.sol";
import "../libraries/LibAppStorage.sol";

contract MarketplaceFacet is IMarketplace {

    /// @notice List an NFT for sale.
    function list(uint256 tokenId, uint256 price) external {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        require(s.erc721OwnerOf[tokenId] == msg.sender, "Not owner");
        s.listings[tokenId] = price;
    }

    /// @notice Buy a listed NFT.
    /// @dev The marketplace IS the diamond, so it manipulates ERC20 and ERC721
    ///      storage directly. This avoids the approve() selector collision between
    ///      ERC20 and ERC721 — both have approve(address,uint256) = 0x095ea7b3.
    ///      Because only one selector can be registered per diamond, we bypass
    ///      the allowance flow and require only that the buyer has sufficient
    ///      ERC20 balance. No prior approve() call needed from the buyer.
    function buy(uint256 tokenId) external {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();

        uint256 price = s.listings[tokenId];
        require(price > 0, "Not listed");

        address seller = s.erc721OwnerOf[tokenId];
        require(seller != address(0), "Token does not exist");

        // ── ERC20 payment: buyer → seller ────────────────────────────────────
        // We skip allowance entirely: the marketplace contract IS the diamond,
        // so it has direct authority over storage. Requiring only a balance
        // check is safe because buy() can only be called intentionally.
        require(s.erc20Balances[msg.sender] >= price, "Insufficient balance");
        s.erc20Balances[msg.sender] -= price;
        s.erc20Balances[seller] += price;

        // ── ERC721 transfer: seller → buyer ──────────────────────────────────
        // The seller must have approved address(this) (the diamond) before
        // listing, OR be the msg.sender. We check the stored approval.
        require(
            s.erc721Approvals[tokenId] == address(this) ||
            s.erc721OperatorApprovals[seller][address(this)],
            "Marketplace not approved for NFT"
        );
        s.erc721Approvals[tokenId] = address(0);
        s.erc721Balances[seller] -= 1;
        s.erc721Balances[msg.sender] += 1;
        s.erc721OwnerOf[tokenId] = msg.sender;

        delete s.listings[tokenId];
    }

    /// @notice Get listing price.
    function getListing(uint256 tokenId) external view returns (uint256) {
        return LibAppStorage.appStorage().listings[tokenId];
    }
}