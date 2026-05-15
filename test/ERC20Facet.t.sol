// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/interfaces/IERC721.sol";
import "../contracts/interfaces/IERC20.sol";
import "../contracts/interfaces/IERC165.sol";
import "../contracts/libraries/LibDiamond.sol";
import "../contracts/libraries/LibAppStorage.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "../contracts/facets/ERC721Facet.sol";
import "../contracts/facets/MintFacet.sol";
import "../contracts/facets/NFTAdminFacet.sol";
import "../contracts/facets/ERC20Facet.sol";
import "../contracts/Diamond.sol";
import "../contracts/upgradeInitializers/DiamondInit.sol";
import "../test/helpers/DiamondUpgradeHelper.sol";

contract ERC20FacetTest is Test, DiamondUpgradeHelper {
    Diamond diamond;
    ERC721Facet erc721;
    MintFacet mintFacet;
    NFTAdminFacet adminFacet;
    DiamondLoupeFacet loupe;
    ERC20Facet erc20;

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

        DiamondInit diamondInit = new DiamondInit();

        address[] memory facetAddresses = new address[](6);
        facetAddresses[0] = address(diamondLoupeFacet);
        facetAddresses[1] = address(ownershipFacet);
        facetAddresses[2] = address(_erc721Facet);
        facetAddresses[3] = address(_mintFacet);
        facetAddresses[4] = address(_adminFacet);
        facetAddresses[5] = address(_erc20Facet);

        string[] memory facetNames = new string[](6);
        facetNames[0] = "DiamondLoupeFacet";
        facetNames[1] = "OwnershipFacet";
        facetNames[2] = "ERC721Facet";
        facetNames[3] = "MintFacet";
        facetNames[4] = "NFTAdminFacet";
        facetNames[5] = "ERC20Facet";

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
        loupe = DiamondLoupeFacet(address(diamond));
        erc20 = ERC20Facet(address(diamond));

        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        vm.deal(user3, 100 ether);
    }

    function test_erc20_name() public {
        assertEq(erc20.nameERC20(), "Diamond Token");
    }

    function test_erc20_symbol() public {
        assertEq(erc20.symbolERC20(), "DTKN");
    }

    function test_erc20_decimals() public {
        assertEq(erc20.decimalsERC20(), 18);
    }

    function test_erc20_initial_supply() public {
        assertEq(erc20.totalSupplyERC20(), 0);
    }

    function test_erc20_initial_balance() public {
        assertEq(erc20.balanceOfERC20(user1), 0);
    }

    function test_erc20_mint() public {
        erc20.mintERC20(user1, 1000 ether);
        assertEq(erc20.balanceOfERC20(user1), 1000 ether);
        assertEq(erc20.totalSupplyERC20(), 1000 ether);
    }

    function test_erc20_mint_exceeds_max() public {
        vm.expectRevert(
            abi.encodeWithSignature("ERC20ExceedsMaxSupply(uint256,uint256)", 1000001 ether, 1000000 ether)
        );
        erc20.mintERC20(user1, 1000001 ether);
    }

    function test_erc20_mint_zero_address() public {
        vm.expectRevert(
            abi.encodeWithSignature("ERC20InvalidReceiver(address)", address(0))
        );
        erc20.mintERC20(address(0), 100 ether);
    }

    function test_erc20_transfer() public {
        erc20.mintERC20(user1, 1000 ether);
        vm.prank(user1);
        erc20.transfer(user2, 500 ether);
        assertEq(erc20.balanceOfERC20(user1), 500 ether);
        assertEq(erc20.balanceOfERC20(user2), 500 ether);
    }

    function test_erc20_transfer_insufficient() public {
        erc20.mintERC20(user1, 100 ether);
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSignature("ERC20InsufficientBalance(address,uint256,uint256)", user1, 100 ether, 200 ether)
        );
        erc20.transfer(user2, 200 ether);
    }

    function test_erc20_transfer_invalid_sender() public {
        vm.expectRevert(
            abi.encodeWithSignature("ERC20InsufficientBalance(address,uint256,uint256)", address(this), 0, 100 ether)
        );
        erc20.transfer(user2, 100 ether);
    }

    function test_erc20_transfer_invalid_receiver() public {
        erc20.mintERC20(user1, 100 ether);
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSignature("ERC20InvalidReceiver(address)", address(0))
        );
        erc20.transfer(address(0), 50 ether);
    }

    function test_erc20_approve() public {
        vm.prank(user1);
        erc20.approveERC20(user2, 500 ether);
        assertEq(erc20.allowance(user1, user2), 500 ether);
    }

    function test_erc20_approve_and_transferFrom() public {
        erc20.mintERC20(user1, 1000 ether);
        vm.prank(user1);
        erc20.approveERC20(user2, 500 ether);

        vm.prank(user2);
        erc20.transferFromERC20(user1, user3, 300 ether);
        assertEq(erc20.balanceOfERC20(user3), 300 ether);
        assertEq(erc20.allowance(user1, user2), 200 ether);
    }

    function test_erc20_transferFrom_insufficient_allowance() public {
        erc20.mintERC20(user1, 1000 ether);
        vm.prank(user1);
        erc20.approveERC20(user2, 100 ether);

        vm.prank(user2);
        vm.expectRevert(
            abi.encodeWithSignature("ERC20InsufficientAllowance(address,uint256,uint256)", user2, 100 ether, 200 ether)
        );
        erc20.transferFromERC20(user1, user3, 200 ether);
    }

    function test_erc20_burn() public {
        erc20.mintERC20(user1, 1000 ether);
        erc20.burnERC20(user1, 500 ether);
        assertEq(erc20.balanceOfERC20(user1), 500 ether);
        assertEq(erc20.totalSupplyERC20(), 500 ether);
    }

    function test_erc20_burn_self() public {
        erc20.mintERC20(user1, 1000 ether);
        vm.prank(user1);
        erc20.burnERC20();
        assertEq(erc20.balanceOfERC20(user1), 0);
        assertEq(erc20.totalSupplyERC20(), 0);
    }

    function test_erc20_burn_insufficient() public {
        erc20.mintERC20(user1, 100 ether);
        vm.expectRevert(
            abi.encodeWithSignature("ERC20InsufficientBalance(address,uint256,uint256)", user1, 100 ether, 200 ether)
        );
        erc20.burnERC20(user1, 200 ether);
    }

    function test_erc20_transfer_emits_event() public {
        erc20.mintERC20(user1, 1000 ether);
        vm.prank(user1);
        vm.expectEmit(true, true, false, true);
        emit IERC20.Transfer(user1, user2, 500 ether);
        erc20.transfer(user2, 500 ether);
    }

    function test_erc20_approve_emits_event() public {
        vm.prank(user1);
        vm.expectEmit(true, true, false, true);
        emit IERC20.Approval(user1, user2, 500 ether);
        erc20.approveERC20(user2, 500 ether);
    }

    function test_erc20_supportsInterface() public {
        assertTrue(loupe.supportsInterface(type(IERC20).interfaceId));
    }
}
