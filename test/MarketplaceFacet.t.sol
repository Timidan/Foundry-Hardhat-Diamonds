// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/interfaces/IERC721.sol";
import "../contracts/interfaces/IERC20.sol";
import "../contracts/interfaces/IERC165.sol";
import "../contracts/interfaces/IMarketplaceFacet.sol";
import "../contracts/libraries/LibDiamond.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "../contracts/facets/ERC721Facet.sol";
import "../contracts/facets/MintFacet.sol";
import "../contracts/facets/NFTAdminFacet.sol";
import "../contracts/facets/ERC20Facet.sol";
import "../contracts/facets/MarketplaceFacet.sol";
import "../contracts/Diamond.sol";
import "../contracts/upgradeInitializers/DiamondInit.sol";
import "../test/helpers/DiamondUpgradeHelper.sol";

contract MarketplaceFacetTest is Test, DiamondUpgradeHelper {
    Diamond diamond;
    ERC721Facet erc721;
    MintFacet mintFacet;
    NFTAdminFacet adminFacet;
    ERC20Facet erc20;
    MarketplaceFacet marketplaceFacet;

    address owner = address(this);
    address user1 = address(0xA11CE);
    address user2 = address(0xB0B);
    address user3 = address(0xC0D3);

    receive() external payable {}

    function setUp() public {
        DiamondCutFacet diamondCutFacet = new DiamondCutFacet();
        diamond = new Diamond(owner, address(diamondCutFacet));

        DiamondLoupeFacet diamondLoupeFacet = new DiamondLoupeFacet();
        OwnershipFacet ownershipFacet = new OwnershipFacet();
        ERC721Facet _erc721Facet = new ERC721Facet();
        MintFacet _mintFacet = new MintFacet();
        NFTAdminFacet _adminFacet = new NFTAdminFacet();
        ERC20Facet _erc20Facet = new ERC20Facet();
        MarketplaceFacet _marketplaceFacet = new MarketplaceFacet();

        DiamondInit diamondInit = new DiamondInit();

        address[] memory facetAddresses = new address[](7);
        facetAddresses[0] = address(diamondLoupeFacet);
        facetAddresses[1] = address(ownershipFacet);
        facetAddresses[2] = address(_erc721Facet);
        facetAddresses[3] = address(_mintFacet);
        facetAddresses[4] = address(_adminFacet);
        facetAddresses[5] = address(_erc20Facet);
        facetAddresses[6] = address(_marketplaceFacet);

        string[] memory facetNames = new string[](7);
        facetNames[0] = "DiamondLoupeFacet";
        facetNames[1] = "OwnershipFacet";
        facetNames[2] = "ERC721Facet";
        facetNames[3] = "MintFacet";
        facetNames[4] = "NFTAdminFacet";
        facetNames[5] = "ERC20Facet";
        facetNames[6] = "MarketplaceFacet";

        IDiamondCut.FacetCut[] memory cuts = buildAddCutsByNames(
            facetAddresses,
            facetNames
        );

        bytes memory initCalldata = abi.encodeWithSelector(
            diamondInit.init.selector,
            DiamondInit.InitParams({
                name: "Diamond NFT",
                symbol: "DNFT",
                baseTokenURI: "https://api.example.com/metadata/",
                maxSupply: 100,
                mintPrice: 0.05 ether,
                erc20Name: "Diamond Token",
                erc20Symbol: "DTKN",
                erc20Decimals: 18,
                erc20MaxSupply: 1000000 ether,
                rewardRate: 10 ether,
                minStakeDuration: 1 days,
                borrowFee: 0.01 ether,
                maxBorrowDuration: 30 days,
                marketplaceFee: 250
            })
        );

        executeDiamondCut(
            IDiamondCut(address(diamond)),
            cuts,
            address(diamondInit),
            initCalldata
        );

        erc721 = ERC721Facet(address(diamond));
        mintFacet = MintFacet(address(diamond));
        adminFacet = NFTAdminFacet(address(diamond));
        erc20 = ERC20Facet(address(diamond));
        marketplaceFacet = MarketplaceFacet(address(diamond));

        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        vm.deal(user3, 100 ether);
    }

    function _mintToken(address to) internal returns (uint256) {
        adminFacet.setMintActive(true);
        uint256 beforeSupply = mintFacet.totalSupply();
        vm.prank(to);
        mintFacet.mint{value: 0.05 ether}();
        return beforeSupply + 1;
    }

    function test_initial_marketplace_state() public {
        assertEq(marketplaceFacet.marketplaceFee(), 250);
    }

    function test_list_nft() public {
        uint256 tokenId = _mintToken(user1);

        vm.prank(user1);
        marketplaceFacet.listNFT(tokenId, 100 ether);

        assertTrue(marketplaceFacet.isListed(tokenId));
        IMarketplaceFacet.Listing memory listing = marketplaceFacet.getListing(tokenId);
        assertEq(listing.seller, user1);
        assertEq(listing.price, 100 ether);
        assertTrue(listing.active);
    }

    function test_list_nft_escrows_nft() public {
        uint256 tokenId = _mintToken(user1);

        vm.prank(user1);
        marketplaceFacet.listNFT(tokenId, 100 ether);

        assertEq(erc721.ownerOf(tokenId), address(diamond));
        assertEq(erc721.balanceOf(user1), 0);
    }

    function test_list_nft_emits_event() public {
        uint256 tokenId = _mintToken(user1);

        vm.prank(user1);
        vm.expectEmit(true, true, false, true);
        emit MarketplaceFacet.NFTListed(tokenId, user1, 100 ether);
        marketplaceFacet.listNFT(tokenId, 100 ether);
    }

    function test_list_not_owner() public {
        uint256 tokenId = _mintToken(user1);

        vm.prank(user2);
        vm.expectRevert(
            abi.encodeWithSignature("TokenNotOwned(uint256)", tokenId)
        );
        marketplaceFacet.listNFT(tokenId, 100 ether);
    }

    function test_list_already_listed() public {
        uint256 tokenId = _mintToken(user1);

        vm.prank(user1);
        marketplaceFacet.listNFT(tokenId, 100 ether);

        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSignature("TokenAlreadyListed(uint256)", tokenId)
        );
        marketplaceFacet.listNFT(tokenId, 200 ether);
    }

    function test_list_invalid_price() public {
        uint256 tokenId = _mintToken(user1);

        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSignature("InvalidPrice()")
        );
        marketplaceFacet.listNFT(tokenId, 0);
    }

    function test_buy_nft() public {
        uint256 tokenId = _mintToken(user1);

        vm.prank(user1);
        marketplaceFacet.listNFT(tokenId, 100 ether);

        erc20.mintERC20(user2, 200 ether);

        vm.prank(user2);
        marketplaceFacet.buyNFT{value: 100 ether}(tokenId);

        assertEq(erc721.ownerOf(tokenId), user2);
        assertEq(erc721.balanceOf(user2), 1);
        assertFalse(marketplaceFacet.isListed(tokenId));
    }

    function test_buy_nft_emits_event() public {
        uint256 tokenId = _mintToken(user1);

        vm.prank(user1);
        marketplaceFacet.listNFT(tokenId, 100 ether);

        erc20.mintERC20(user2, 200 ether);

        vm.prank(user2);
        vm.expectEmit(true, true, true, false);
        emit MarketplaceFacet.NFTSold(tokenId, user1, user2, 100 ether);
        marketplaceFacet.buyNFT{value: 100 ether}(tokenId);
    }

    function test_buy_nft_with_fee() public {
        uint256 tokenId = _mintToken(user1);

        vm.prank(user1);
        marketplaceFacet.listNFT(tokenId, 100 ether);

        erc20.mintERC20(user2, 200 ether);

        uint256 sellerBalanceBefore = erc20.balanceOfERC20(user1);
        address diamondOwner = owner;
        uint256 ownerBalanceBefore = erc20.balanceOfERC20(diamondOwner);

        vm.prank(user2);
        marketplaceFacet.buyNFT{value: 100 ether}(tokenId);

        uint256 fee = (100 ether * 250) / 10000;
        assertEq(erc20.balanceOfERC20(user1) - sellerBalanceBefore, 100 ether - fee);
        assertEq(erc20.balanceOfERC20(diamondOwner) - ownerBalanceBefore, fee);
    }

    function test_buy_nft_deducts_buyer_balance() public {
        uint256 tokenId = _mintToken(user1);

        vm.prank(user1);
        marketplaceFacet.listNFT(tokenId, 100 ether);

        erc20.mintERC20(user2, 200 ether);

        vm.prank(user2);
        marketplaceFacet.buyNFT{value: 100 ether}(tokenId);

        assertEq(erc20.balanceOfERC20(user2), 100 ether);
    }

    function test_buy_not_listed() public {
        uint256 tokenId = _mintToken(user1);

        vm.prank(user2);
        vm.expectRevert(
            abi.encodeWithSignature("ListingNotActive(uint256)", tokenId)
        );
        marketplaceFacet.buyNFT{value: 100 ether}(tokenId);
    }

    function test_buy_insufficient_payment() public {
        uint256 tokenId = _mintToken(user1);

        vm.prank(user1);
        marketplaceFacet.listNFT(tokenId, 100 ether);

        vm.prank(user2);
        vm.expectRevert(
            abi.encodeWithSignature("InsufficientPayment(uint256,uint256)", 50 ether, 100 ether)
        );
        marketplaceFacet.buyNFT{value: 50 ether}(tokenId);
    }

    function test_buy_insufficient_erc20_balance() public {
        uint256 tokenId = _mintToken(user1);

        vm.prank(user1);
        marketplaceFacet.listNFT(tokenId, 100 ether);

        erc20.mintERC20(user2, 50 ether);

        vm.prank(user2);
        vm.expectRevert();
        marketplaceFacet.buyNFT{value: 100 ether}(tokenId);
    }

    function test_delist_nft() public {
        uint256 tokenId = _mintToken(user1);

        vm.prank(user1);
        marketplaceFacet.listNFT(tokenId, 100 ether);

        vm.prank(user1);
        marketplaceFacet.delistNFT(tokenId);

        assertFalse(marketplaceFacet.isListed(tokenId));
        assertEq(erc721.ownerOf(tokenId), user1);
        assertEq(erc721.balanceOf(user1), 1);
    }

    function test_delist_nft_emits_event() public {
        uint256 tokenId = _mintToken(user1);

        vm.prank(user1);
        marketplaceFacet.listNFT(tokenId, 100 ether);

        vm.prank(user1);
        vm.expectEmit(true, true, false, true);
        emit MarketplaceFacet.NFTDelisted(tokenId, user1);
        marketplaceFacet.delistNFT(tokenId);
    }

    function test_delist_unauthorized() public {
        uint256 tokenId = _mintToken(user1);

        vm.prank(user1);
        marketplaceFacet.listNFT(tokenId, 100 ether);

        vm.prank(user2);
        vm.expectRevert(
            abi.encodeWithSignature("Unauthorized()")
        );
        marketplaceFacet.delistNFT(tokenId);
    }

    function test_delist_not_active() public {
        uint256 tokenId = _mintToken(user1);

        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSignature("ListingNotActive(uint256)", tokenId)
        );
        marketplaceFacet.delistNFT(tokenId);
    }

    function test_get_listings() public {
        uint256 tokenId1 = _mintToken(user1);
        uint256 tokenId2 = _mintToken(user1);

        vm.prank(user1);
        marketplaceFacet.listNFT(tokenId1, 100 ether);
        vm.prank(user1);
        marketplaceFacet.listNFT(tokenId2, 200 ether);

        IMarketplaceFacet.Listing[] memory listings = marketplaceFacet.getListings();
        assertEq(listings.length, 2);
    }

    function test_get_listings_after_delist() public {
        uint256 tokenId1 = _mintToken(user1);
        uint256 tokenId2 = _mintToken(user1);

        vm.prank(user1);
        marketplaceFacet.listNFT(tokenId1, 100 ether);
        vm.prank(user1);
        marketplaceFacet.listNFT(tokenId2, 200 ether);

        vm.prank(user1);
        marketplaceFacet.delistNFT(tokenId1);

        IMarketplaceFacet.Listing[] memory listings = marketplaceFacet.getListings();
        assertEq(listings.length, 1);
        assertEq(listings[0].tokenId, tokenId2);
    }

    function test_get_listings_empty() public {
        IMarketplaceFacet.Listing[] memory listings = marketplaceFacet.getListings();
        assertEq(listings.length, 0);
    }

    function test_set_marketplace_fee() public {
        marketplaceFacet.setMarketplaceFee(500);
        assertEq(marketplaceFacet.marketplaceFee(), 500);
    }

    function test_set_marketplace_fee_emits_event() public {
        vm.expectEmit(false, false, false, true);
        emit MarketplaceFacet.MarketplaceFeeUpdated(250, 500);
        marketplaceFacet.setMarketplaceFee(500);
    }

    function test_set_marketplace_fee_too_high() public {
        vm.expectRevert(
            abi.encodeWithSignature("InvalidFee()")
        );
        marketplaceFacet.setMarketplaceFee(1001);
    }

    function test_multiple_list_and_buy() public {
        uint256 tokenId1 = _mintToken(user1);
        uint256 tokenId2 = _mintToken(user1);

        vm.prank(user1);
        marketplaceFacet.listNFT(tokenId1, 100 ether);
        vm.prank(user1);
        marketplaceFacet.listNFT(tokenId2, 200 ether);

        erc20.mintERC20(user2, 500 ether);
        vm.deal(user2, 500 ether);

        vm.prank(user2);
        marketplaceFacet.buyNFT{value: 100 ether}(tokenId1);

        vm.prank(user2);
        marketplaceFacet.buyNFT{value: 200 ether}(tokenId2);

        assertEq(erc721.ownerOf(tokenId1), user2);
        assertEq(erc721.ownerOf(tokenId2), user2);
        assertFalse(marketplaceFacet.isListed(tokenId1));
        assertFalse(marketplaceFacet.isListed(tokenId2));
    }

    function test_buy_already_sold() public {
        uint256 tokenId = _mintToken(user1);

        vm.prank(user1);
        marketplaceFacet.listNFT(tokenId, 100 ether);

        erc20.mintERC20(user2, 200 ether);

        vm.prank(user2);
        marketplaceFacet.buyNFT{value: 100 ether}(tokenId);

        vm.prank(user3);
        vm.expectRevert(
            abi.encodeWithSignature("ListingNotActive(uint256)", tokenId)
        );
        marketplaceFacet.buyNFT{value: 100 ether}(tokenId);
    }

    function test_listing_details() public {
        uint256 tokenId = _mintToken(user1);

        vm.prank(user1);
        marketplaceFacet.listNFT(tokenId, 100 ether);

        IMarketplaceFacet.Listing memory listing = marketplaceFacet.getListing(tokenId);
        assertEq(listing.tokenId, tokenId);
        assertEq(listing.seller, user1);
        assertEq(listing.price, 100 ether);
        assertTrue(listing.active);
    }
}
