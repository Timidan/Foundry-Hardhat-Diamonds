// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/interfaces/IERC721.sol";
import "../contracts/interfaces/IERC165.sol";
import "../contracts/interfaces/IBorrowerFacet.sol";
import "../contracts/libraries/LibDiamond.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "../contracts/facets/ERC721Facet.sol";
import "../contracts/facets/MintFacet.sol";
import "../contracts/facets/NFTAdminFacet.sol";
import "../contracts/facets/BorrowerFacet.sol";
import "../contracts/Diamond.sol";
import "../contracts/upgradeInitializers/DiamondInit.sol";
import "../test/helpers/DiamondUpgradeHelper.sol";

contract BorrowerFacetTest is Test, DiamondUpgradeHelper {
    Diamond diamond;
    ERC721Facet erc721;
    MintFacet mintFacet;
    NFTAdminFacet adminFacet;
    BorrowerFacet borrowerFacet;

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
        BorrowerFacet _borrowerFacet = new BorrowerFacet();

        DiamondInit diamondInit = new DiamondInit();

        address[] memory facetAddresses = new address[](6);
        facetAddresses[0] = address(diamondLoupeFacet);
        facetAddresses[1] = address(ownershipFacet);
        facetAddresses[2] = address(_erc721Facet);
        facetAddresses[3] = address(_mintFacet);
        facetAddresses[4] = address(_adminFacet);
        facetAddresses[5] = address(_borrowerFacet);

        string[] memory facetNames = new string[](6);
        facetNames[0] = "DiamondLoupeFacet";
        facetNames[1] = "OwnershipFacet";
        facetNames[2] = "ERC721Facet";
        facetNames[3] = "MintFacet";
        facetNames[4] = "NFTAdminFacet";
        facetNames[5] = "BorrowerFacet";

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
        borrowerFacet = BorrowerFacet(address(diamond));

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

    function test_initial_borrow_state() public {
        assertEq(borrowerFacet.borrowFee(), 0.01 ether);
        assertEq(borrowerFacet.maxBorrowDuration(), 30 days);
    }

    function test_borrow_token() public {
        uint256 tokenId = _mintToken(user1);

        vm.prank(user2);
        borrowerFacet.borrowToken{value: 0.01 ether}(tokenId, 7 days);

        assertTrue(borrowerFacet.isBorrowed(tokenId));
        assertEq(erc721.ownerOf(tokenId), user2);
        assertEq(erc721.balanceOf(user2), 1);
        assertEq(erc721.balanceOf(user1), 0);
    }

    function test_borrow_emits_event() public {
        uint256 tokenId = _mintToken(user1);

        vm.prank(user2);
        vm.expectEmit(true, true, false, true);
        emit BorrowerFacet.TokenBorrowed(user2, tokenId, 7 days, 0.01 ether, block.timestamp + 7 days);
        borrowerFacet.borrowToken{value: 0.01 ether}(tokenId, 7 days);
    }

    function test_borrow_insufficient_fee() public {
        uint256 tokenId = _mintToken(user1);

        vm.prank(user2);
        vm.expectRevert(
            abi.encodeWithSignature("InsufficientFee(uint256,uint256)", 0.005 ether, 0.01 ether)
        );
        borrowerFacet.borrowToken{value: 0.005 ether}(tokenId, 7 days);
    }

    function test_borrow_duration_too_long() public {
        uint256 tokenId = _mintToken(user1);

        vm.prank(user2);
        vm.expectRevert(
            abi.encodeWithSignature("DurationTooLong(uint256)", 365 days)
        );
        borrowerFacet.borrowToken{value: 0.01 ether}(tokenId, 365 days);
    }

    function test_borrow_not_owned() public {
        uint256 tokenId = _mintToken(user1);

        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSignature("TokenNotOwned(uint256)", tokenId)
        );
        borrowerFacet.borrowToken{value: 0.01 ether}(tokenId, 7 days);
    }

    function test_borrow_already_borrowed() public {
        uint256 tokenId = _mintToken(user1);

        vm.prank(user2);
        borrowerFacet.borrowToken{value: 0.01 ether}(tokenId, 7 days);

        vm.prank(user3);
        vm.expectRevert(
            abi.encodeWithSignature("TokenAlreadyBorrowed(uint256)", tokenId)
        );
        borrowerFacet.borrowToken{value: 0.01 ether}(tokenId, 7 days);
    }

    function test_return_token() public {
        uint256 tokenId = _mintToken(user1);

        vm.prank(user2);
        borrowerFacet.borrowToken{value: 0.01 ether}(tokenId, 7 days);

        vm.warp(block.timestamp + 8 days);

        vm.prank(user2);
        borrowerFacet.returnToken(tokenId);

        assertFalse(borrowerFacet.isBorrowed(tokenId));
        assertEq(erc721.ownerOf(tokenId), user1);
        assertEq(erc721.balanceOf(user1), 1);
        assertEq(erc721.balanceOf(user2), 0);
    }

    function test_return_emits_event() public {
        uint256 tokenId = _mintToken(user1);

        vm.prank(user2);
        borrowerFacet.borrowToken{value: 0.01 ether}(tokenId, 7 days);

        vm.warp(block.timestamp + 8 days);

        vm.prank(user2);
        vm.expectEmit(true, true, false, true);
        emit BorrowerFacet.TokenReturned(user2, tokenId);
        borrowerFacet.returnToken(tokenId);
    }

    function test_return_before_deadline() public {
        uint256 tokenId = _mintToken(user1);

        vm.prank(user2);
        borrowerFacet.borrowToken{value: 0.01 ether}(tokenId, 7 days);

        vm.prank(user2);
        vm.expectRevert(
            abi.encodeWithSignature("BorrowNotExpired(uint256)", tokenId)
        );
        borrowerFacet.returnToken(tokenId);
    }

    function test_return_not_borrowed() public {
        uint256 tokenId = _mintToken(user1);

        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSignature("TokenNotBorrowed(uint256)", tokenId)
        );
        borrowerFacet.returnToken(tokenId);
    }

    function test_return_unauthorized() public {
        uint256 tokenId = _mintToken(user1);

        vm.prank(user2);
        borrowerFacet.borrowToken{value: 0.01 ether}(tokenId, 7 days);

        vm.warp(block.timestamp + 8 days);

        vm.prank(user3);
        vm.expectRevert(
            abi.encodeWithSignature("Unauthorized()")
        );
        borrowerFacet.returnToken(tokenId);
    }

    function test_borrow_info() public {
        uint256 tokenId = _mintToken(user1);

        vm.prank(user2);
        borrowerFacet.borrowToken{value: 0.01 ether}(tokenId, 7 days);

        (address borrower, uint256 deadline, uint256 fee, bool active) = borrowerFacet.getBorrowInfo(tokenId);
        assertEq(borrower, user2);
        assertEq(fee, 0.01 ether);
        assertTrue(active);
        assertEq(deadline, block.timestamp + 7 days);
    }

    function test_borrow_info_not_borrowed() public {
        (, , uint256 fee, bool active) = borrowerFacet.getBorrowInfo(1);
        assertFalse(active);
        assertEq(fee, 0);
    }

    function test_set_borrow_fee() public {
        borrowerFacet.setBorrowFee(0.05 ether);
        assertEq(borrowerFacet.borrowFee(), 0.05 ether);
    }

    function test_set_borrow_fee_emits_event() public {
        vm.expectEmit(false, false, false, true);
        emit BorrowerFacet.BorrowFeeUpdated(0.01 ether, 0.05 ether);
        borrowerFacet.setBorrowFee(0.05 ether);
    }

    function test_set_max_borrow_duration() public {
        borrowerFacet.setMaxBorrowDuration(60 days);
        assertEq(borrowerFacet.maxBorrowDuration(), 60 days);
    }

    function test_set_max_borrow_duration_emits_event() public {
        vm.expectEmit(false, false, false, true);
        emit BorrowerFacet.MaxBorrowDurationUpdated(30 days, 60 days);
        borrowerFacet.setMaxBorrowDuration(60 days);
    }

    function test_borrow_with_exact_fee() public {
        uint256 tokenId = _mintToken(user1);

        vm.prank(user2);
        borrowerFacet.borrowToken{value: 0.01 ether}(tokenId, 7 days);

        assertTrue(borrowerFacet.isBorrowed(tokenId));
    }

    function test_borrow_with_extra_fee() public {
        uint256 tokenId = _mintToken(user1);

        vm.prank(user2);
        borrowerFacet.borrowToken{value: 0.05 ether}(tokenId, 7 days);

        assertTrue(borrowerFacet.isBorrowed(tokenId));
    }

    function test_multiple_borrows() public {
        uint256 tokenId1 = _mintToken(user1);
        uint256 tokenId2 = _mintToken(user1);

        vm.prank(user2);
        borrowerFacet.borrowToken{value: 0.01 ether}(tokenId1, 7 days);

        vm.prank(user3);
        borrowerFacet.borrowToken{value: 0.01 ether}(tokenId2, 14 days);

        assertTrue(borrowerFacet.isBorrowed(tokenId1));
        assertTrue(borrowerFacet.isBorrowed(tokenId2));
    }

    function test_return_first_borrow_second_still_active() public {
        uint256 tokenId1 = _mintToken(user1);
        uint256 tokenId2 = _mintToken(user1);

        vm.prank(user2);
        borrowerFacet.borrowToken{value: 0.01 ether}(tokenId1, 7 days);

        vm.prank(user3);
        borrowerFacet.borrowToken{value: 0.01 ether}(tokenId2, 14 days);

        vm.warp(block.timestamp + 8 days);

        vm.prank(user2);
        borrowerFacet.returnToken(tokenId1);

        assertFalse(borrowerFacet.isBorrowed(tokenId1));
        assertTrue(borrowerFacet.isBorrowed(tokenId2));
    }
}
