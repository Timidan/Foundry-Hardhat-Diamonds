// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/interfaces/IERC721.sol";
import "../contracts/interfaces/IERC165.sol";
import "../contracts/libraries/LibDiamond.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "../contracts/facets/ERC721Facet.sol";
import "../contracts/facets/MintFacet.sol";
import "../contracts/facets/NFTAdminFacet.sol";
import "../contracts/Diamond.sol";
import "../contracts/upgradeInitializers/DiamondInit.sol";
import "./helpers/DiamondUpgradeHelper.sol";

contract ERC721DiamondTest is Test, DiamondUpgradeHelper {
    Diamond diamond;
    ERC721Facet erc721;
    MintFacet mintFacet;
    NFTAdminFacet adminFacet;
    DiamondLoupeFacet loupe;

    address owner = address(this);
    address user1 = address(0xA11CE);
    address user2 = address(0xB0B);

    receive() external payable {}

    function setUp() public {
        // Deploy DiamondCutFacet
        DiamondCutFacet diamondCutFacet = new DiamondCutFacet();

        // Deploy Diamond
        diamond = new Diamond(owner, address(diamondCutFacet));

        // Deploy all facets
        DiamondLoupeFacet diamondLoupeFacet = new DiamondLoupeFacet();
        OwnershipFacet ownershipFacet = new OwnershipFacet();
        ERC721Facet _erc721Facet = new ERC721Facet();
        MintFacet _mintFacet = new MintFacet();
        NFTAdminFacet _adminFacet = new NFTAdminFacet();

        // Deploy DiamondInit
        DiamondInit diamondInit = new DiamondInit();

        // Build cuts
        address[] memory facetAddresses = new address[](5);
        facetAddresses[0] = address(diamondLoupeFacet);
        facetAddresses[1] = address(ownershipFacet);
        facetAddresses[2] = address(_erc721Facet);
        facetAddresses[3] = address(_mintFacet);
        facetAddresses[4] = address(_adminFacet);

        string[] memory facetNames = new string[](5);
        facetNames[0] = "DiamondLoupeFacet";
        facetNames[1] = "OwnershipFacet";
        facetNames[2] = "ERC721Facet";
        facetNames[3] = "MintFacet";
        facetNames[4] = "NFTAdminFacet";

        IDiamondCut.FacetCut[] memory cuts = buildAddCutsByNames(
            facetAddresses,
            facetNames
        );

        // Encode init calldata
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

        // Execute diamond cut with init
        executeDiamondCut(
            IDiamondCut(address(diamond)),
            cuts,
            address(diamondInit),
            initCalldata
        );

        // Get facet references
        erc721 = ERC721Facet(address(diamond));
        mintFacet = MintFacet(address(diamond));
        adminFacet = NFTAdminFacet(address(diamond));
        loupe = DiamondLoupeFacet(address(diamond));

        // Fund test users
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
    }

    // ==================== Initialization Tests ====================

    function test_name() public {
        assertEq(erc721.name(), "Diamond NFT");
    }

    function test_symbol() public {
        assertEq(erc721.symbol(), "DNFT");
    }

    function test_totalSupply() public {
        assertEq(mintFacet.totalSupply(), 0);
    }

    function test_maxSupply() public {
        assertEq(mintFacet.maxSupply(), 100);
    }

    function test_mintPrice() public {
        assertEq(mintFacet.mintPrice(), 0.05 ether);
    }

    function test_mintActive_false() public {
        assertFalse(mintFacet.mintActive());
    }

    // ==================== Minting Tests ====================

    function test_mint_reverts_when_not_active() public {
        vm.prank(user1);
        vm.expectRevert(MintFacet.MintNotActive.selector);
        mintFacet.mint{value: 0.05 ether}();
    }

    function test_mint_reverts_insufficient_payment() public {
        adminFacet.setMintActive(true);

        vm.prank(user1);
        vm.expectRevert(MintFacet.InsufficientPayment.selector);
        mintFacet.mint{value: 0.01 ether}();
    }

    function test_mint_success() public {
        adminFacet.setMintActive(true);

        vm.prank(user1);
        mintFacet.mint{value: 0.05 ether}();

        assertEq(mintFacet.totalSupply(), 1);
        assertEq(erc721.balanceOf(user1), 1);
        assertEq(erc721.ownerOf(1), user1);
    }

    function test_mintTo_success() public {
        adminFacet.setMintActive(true);

        vm.prank(user1);
        mintFacet.mintTo{value: 0.05 ether}(user2);

        assertEq(mintFacet.totalSupply(), 1);
        assertEq(erc721.balanceOf(user2), 1);
        assertEq(erc721.ownerOf(1), user2);
    }

    function test_mintTo_reverts_zero_address() public {
        adminFacet.setMintActive(true);

        vm.prank(user1);
        vm.expectRevert(MintFacet.InvalidAddress.selector);
        mintFacet.mintTo{value: 0.05 ether}(address(0));
    }

    function test_mint_reverts_max_supply() public {
        adminFacet.setMaxSupply(1);
        adminFacet.setMintActive(true);

        vm.prank(user1);
        mintFacet.mint{value: 0.05 ether}();

        vm.prank(user2);
        vm.expectRevert(MintFacet.MaxSupplyReached.selector);
        mintFacet.mint{value: 0.05 ether}();
    }

    function test_multiple_mints() public {
        adminFacet.setMintActive(true);

        vm.prank(user1);
        mintFacet.mint{value: 0.05 ether}();
        vm.prank(user2);
        mintFacet.mint{value: 0.05 ether}();
        vm.prank(user1);
        mintFacet.mint{value: 0.05 ether}();

        assertEq(mintFacet.totalSupply(), 3);
        assertEq(erc721.balanceOf(user1), 2);
        assertEq(erc721.balanceOf(user2), 1);
        assertEq(erc721.ownerOf(1), user1);
        assertEq(erc721.ownerOf(2), user2);
        assertEq(erc721.ownerOf(3), user1);
    }

    // ==================== Transfer Tests ====================

    function _mintToken(address to) internal {
        adminFacet.setMintActive(true);
        vm.prank(to);
        mintFacet.mint{value: 0.05 ether}();
    }

    function test_transferFrom() public {
        _mintToken(user1);

        vm.prank(user1);
        erc721.transferFrom(user1, user2, 1);

        assertEq(erc721.ownerOf(1), user2);
        assertEq(erc721.balanceOf(user1), 0);
        assertEq(erc721.balanceOf(user2), 1);
    }

    function test_transferFrom_reverts_not_owner() public {
        _mintToken(user1);

        vm.prank(user2);
        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC721IncorrectOwner(address,uint256,address)",
                user2,
                1,
                user1
            )
        );
        erc721.transferFrom(user2, user1, 1);
    }

    function test_transferFrom_approved() public {
        _mintToken(user1);

        vm.prank(user1);
        erc721.approve(user2, 1);

        vm.prank(user2);
        erc721.transferFrom(user1, user2, 1);

        assertEq(erc721.ownerOf(1), user2);
    }

    function test_transferFrom_operator() public {
        _mintToken(user1);

        vm.prank(user1);
        erc721.setApprovalForAll(user2, true);

        vm.prank(user2);
        erc721.transferFrom(user1, user2, 1);

        assertEq(erc721.ownerOf(1), user2);
    }

    // ==================== Approval Tests ====================

    function test_approve() public {
        _mintToken(user1);

        vm.prank(user1);
        erc721.approve(user2, 1);

        assertEq(erc721.getApproved(1), user2);
    }

    function test_setApprovalForAll() public {
        vm.prank(user1);
        erc721.setApprovalForAll(user2, true);
        assertTrue(erc721.isApprovedForAll(user1, user2));

        vm.prank(user1);
        erc721.setApprovalForAll(user2, false);
        assertFalse(erc721.isApprovedForAll(user1, user2));
    }

    // ==================== Metadata Tests ====================

    function test_tokenURI() public {
        _mintToken(user1);
        assertEq(
            erc721.tokenURI(1),
            "https://api.example.com/metadata/1"
        );
    }

    function test_tokenURI_updates_with_base() public {
        adminFacet.setBaseTokenURI("ipfs://QmHash/");
        _mintToken(user1);
        assertEq(erc721.tokenURI(1), "ipfs://QmHash/1");
    }

    // ==================== Admin Tests ====================

    function test_setMintActive() public {
        adminFacet.setMintActive(true);
        assertTrue(mintFacet.mintActive());

        adminFacet.setMintActive(false);
        assertFalse(mintFacet.mintActive());
    }

    function test_setMintPrice() public {
        adminFacet.setMintPrice(0.1 ether);
        assertEq(mintFacet.mintPrice(), 0.1 ether);
    }

    function test_withdraw() public {
        adminFacet.setMintActive(true);

        vm.prank(user1);
        mintFacet.mint{value: 0.05 ether}();

        uint256 balanceBefore = owner.balance;
        adminFacet.withdraw();
        uint256 balanceAfter = owner.balance;

        assertEq(balanceAfter - balanceBefore, 0.05 ether);
    }

    function test_withdraw_reverts_non_owner() public {
        vm.prank(user1);
        vm.expectRevert(LibDiamond.NotDiamondOwner.selector);
        adminFacet.withdraw();
    }

    function test_admin_reverts_non_owner() public {
        vm.prank(user1);
        vm.expectRevert(LibDiamond.NotDiamondOwner.selector);
        adminFacet.setMintActive(true);
    }

    // ==================== ERC-165 Tests ====================

    function test_supportsInterface_erc721() public {
        assertTrue(loupe.supportsInterface(type(IERC721).interfaceId));
    }

    function test_supportsInterface_erc721_metadata() public {
        assertTrue(loupe.supportsInterface(type(IERC721Metadata).interfaceId));
    }

    function test_supportsInterface_erc165() public {
        assertTrue(loupe.supportsInterface(type(IERC165).interfaceId));
    }
}
