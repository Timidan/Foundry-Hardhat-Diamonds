// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/interfaces/IERC721.sol";
import "../contracts/interfaces/IERC165.sol";
import "../contracts/interfaces/IOnchainSVG.sol";
import "../contracts/libraries/LibDiamond.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "../contracts/facets/ERC721Facet.sol";
import "../contracts/facets/MintFacet.sol";
import "../contracts/facets/NFTAdminFacet.sol";
import "../contracts/facets/OnchainSVGFacet.sol";
import "../contracts/Diamond.sol";
import "../contracts/upgradeInitializers/DiamondInit.sol";
import "../test/helpers/DiamondUpgradeHelper.sol";

contract OnchainSVGFacetTest is Test, DiamondUpgradeHelper {
    Diamond diamond;
    ERC721Facet erc721;
    MintFacet mintFacet;
    NFTAdminFacet adminFacet;
    OnchainSVGFacet svgFacet;

    address owner = address(this);
    address user1 = address(0xA11CE);
    address user2 = address(0xB0B);

    receive() external payable {}

    function setUp() public {
        DiamondCutFacet diamondCutFacet = new DiamondCutFacet();
        diamond = new Diamond(owner, address(diamondCutFacet));

        DiamondLoupeFacet diamondLoupeFacet = new DiamondLoupeFacet();
        OwnershipFacet ownershipFacet = new OwnershipFacet();
        ERC721Facet _erc721Facet = new ERC721Facet();
        MintFacet _mintFacet = new MintFacet();
        NFTAdminFacet _adminFacet = new NFTAdminFacet();
        OnchainSVGFacet _svgFacet = new OnchainSVGFacet();

        DiamondInit diamondInit = new DiamondInit();

        address[] memory facetAddresses = new address[](6);
        facetAddresses[0] = address(diamondLoupeFacet);
        facetAddresses[1] = address(ownershipFacet);
        facetAddresses[2] = address(_erc721Facet);
        facetAddresses[3] = address(_mintFacet);
        facetAddresses[4] = address(_adminFacet);
        facetAddresses[5] = address(_svgFacet);

        string[] memory facetNames = new string[](6);
        facetNames[0] = "DiamondLoupeFacet";
        facetNames[1] = "OwnershipFacet";
        facetNames[2] = "ERC721Facet";
        facetNames[3] = "MintFacet";
        facetNames[4] = "NFTAdminFacet";
        facetNames[5] = "OnchainSVGFacet";

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
        svgFacet = OnchainSVGFacet(address(diamond));

        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
    }

    function _mintToken(address to) internal returns (uint256) {
        adminFacet.setMintActive(true);
        uint256 beforeSupply = mintFacet.totalSupply();
        vm.prank(to);
        mintFacet.mint{value: 0.05 ether}();
        return beforeSupply + 1;
    }

    function _contains(string memory haystack, string memory needle) internal pure returns (bool) {
        bytes memory h = bytes(haystack);
        bytes memory n = bytes(needle);
        if (n.length > h.length) return false;
        for (uint256 i = 0; i <= h.length - n.length; i++) {
            bool found = true;
            for (uint256 j = 0; j < n.length; j++) {
                if (h[i + j] != n[j]) {
                    found = false;
                    break;
                }
            }
            if (found) return true;
        }
        return false;
    }

    function test_set_shape() public {
        uint256 tokenId = _mintToken(user1);
        vm.prank(user1);
        svgFacet.setTokenShape(tokenId, "diamond");
        assertEq(svgFacet.tokenShape(tokenId), "diamond");
    }

    function test_set_colors() public {
        uint256 tokenId = _mintToken(user1);
        vm.prank(user1);
        svgFacet.setTokenColors(tokenId, "#FF0000", "#00FF00");
        (string memory primary, string memory secondary) = svgFacet.tokenColors(tokenId);
        assertEq(primary, "#FF0000");
        assertEq(secondary, "#00FF00");
    }

    function test_generate_svg() public {
        uint256 tokenId = _mintToken(user1);
        vm.prank(user1);
        svgFacet.setTokenShape(tokenId, "star");
        vm.prank(user1);
        svgFacet.setTokenColors(tokenId, "#FFD700", "#C0C0C0");

        string memory svg = svgFacet.generateSVG(tokenId);
        assertGt(bytes(svg).length, 0);
        assertTrue(_contains(svg, "<svg"));
        assertTrue(_contains(svg, "polygon"));
    }

    function test_default_values() public {
        uint256 tokenId = _mintToken(user1);
        string memory svg = svgFacet.getTokenSVG(tokenId);
        assertGt(bytes(svg).length, 0);
        assertTrue(_contains(svg, "circle"));
        assertTrue(_contains(svg, "#FF6B6B"));
    }

    function test_invalid_shape() public {
        uint256 tokenId = _mintToken(user1);
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSignature("InvalidShape(string)", "pentagon")
        );
        svgFacet.setTokenShape(tokenId, "pentagon");
    }

    function test_unauthorized() public {
        uint256 tokenId = _mintToken(user1);
        vm.prank(user2);
        vm.expectRevert(
            abi.encodeWithSignature("Unauthorized()")
        );
        svgFacet.setTokenShape(tokenId, "square");
    }

    function test_nonexistent_token() public {
        vm.expectRevert(
            abi.encodeWithSignature("TokenDoesNotExist(uint256)", 999)
        );
        svgFacet.generateSVG(999);
    }

    function test_all_shapes() public {
        uint256 tokenId = _mintToken(user1);
        string[6] memory shapes = ["circle", "square", "triangle", "diamond", "hexagon", "star"];

        for (uint256 i = 0; i < shapes.length; i++) {
            vm.prank(user1);
            svgFacet.setTokenShape(tokenId, shapes[i]);
            string memory svg = svgFacet.getTokenSVG(tokenId);
            assertGt(bytes(svg).length, 0);
        }
    }

    function test_shape_emits_event() public {
        uint256 tokenId = _mintToken(user1);
        vm.prank(user1);
        vm.expectEmit(true, false, false, false);
        emit OnchainSVGFacet.ShapeSet(tokenId, "diamond");
        svgFacet.setTokenShape(tokenId, "diamond");
    }

    function test_colors_emits_event() public {
        uint256 tokenId = _mintToken(user1);
        vm.prank(user1);
        vm.expectEmit(true, false, false, false);
        emit OnchainSVGFacet.ColorsSet(tokenId, "#FF0000", "#00FF00");
        svgFacet.setTokenColors(tokenId, "#FF0000", "#00FF00");
    }

    function test_owner_can_set_shape() public {
        uint256 tokenId = _mintToken(user1);
        svgFacet.setTokenShape(tokenId, "hexagon");
        assertEq(svgFacet.tokenShape(tokenId), "hexagon");
    }

    function test_svg_contains_title() public {
        uint256 tokenId = _mintToken(user1);
        string memory svg = svgFacet.getTokenSVG(tokenId);
        assertTrue(_contains(svg, "Token #"));
    }

    function test_svg_contains_background() public {
        uint256 tokenId = _mintToken(user1);
        string memory svg = svgFacet.getTokenSVG(tokenId);
        assertTrue(_contains(svg, "#1a1a2e"));
    }
}
