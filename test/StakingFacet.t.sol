// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/interfaces/IERC721.sol";
import "../contracts/interfaces/IERC20.sol";
import "../contracts/interfaces/IERC165.sol";
import "../contracts/interfaces/IStakingFacet.sol";
import "../contracts/libraries/LibDiamond.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";
import "../contracts/facets/ERC721Facet.sol";
import "../contracts/facets/MintFacet.sol";
import "../contracts/facets/NFTAdminFacet.sol";
import "../contracts/facets/ERC20Facet.sol";
import "../contracts/facets/StakingFacet.sol";
import "../contracts/Diamond.sol";
import "../contracts/upgradeInitializers/DiamondInit.sol";
import "../test/helpers/DiamondUpgradeHelper.sol";

contract StakingFacetTest is Test, DiamondUpgradeHelper {
    Diamond diamond;
    ERC721Facet erc721;
    MintFacet mintFacet;
    NFTAdminFacet adminFacet;
    ERC20Facet erc20;
    StakingFacet stakingFacet;

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
        ERC20Facet _erc20Facet = new ERC20Facet();
        StakingFacet _stakingFacet = new StakingFacet();

        DiamondInit diamondInit = new DiamondInit();

        address[] memory facetAddresses = new address[](7);
        facetAddresses[0] = address(diamondLoupeFacet);
        facetAddresses[1] = address(ownershipFacet);
        facetAddresses[2] = address(_erc721Facet);
        facetAddresses[3] = address(_mintFacet);
        facetAddresses[4] = address(_adminFacet);
        facetAddresses[5] = address(_erc20Facet);
        facetAddresses[6] = address(_stakingFacet);

        string[] memory facetNames = new string[](7);
        facetNames[0] = "DiamondLoupeFacet";
        facetNames[1] = "OwnershipFacet";
        facetNames[2] = "ERC721Facet";
        facetNames[3] = "MintFacet";
        facetNames[4] = "NFTAdminFacet";
        facetNames[5] = "ERC20Facet";
        facetNames[6] = "StakingFacet";

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
        stakingFacet = StakingFacet(address(diamond));

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

    function test_initial_staking_state() public {
        assertEq(stakingFacet.totalStaked(), 0);
        assertEq(stakingFacet.rewardRate(), 10 ether);
        assertEq(stakingFacet.minStakeDuration(), 1 days);
    }

    function test_stake_success() public {
        uint256 tokenId = _mintToken(user1);
        vm.prank(user1);
        erc721.approve(address(diamond), tokenId);
        vm.prank(user1);
        stakingFacet.stake(tokenId);

        assertEq(stakingFacet.totalStaked(), 1);
        (address staker, , ) = stakingFacet.getStakingInfo(tokenId);
        assertEq(staker, user1);
    }

    function test_stake_transfers_nft_to_diamond() public {
        uint256 tokenId = _mintToken(user1);
        vm.prank(user1);
        erc721.approve(address(diamond), tokenId);
        vm.prank(user1);
        stakingFacet.stake(tokenId);

        assertEq(erc721.ownerOf(tokenId), address(diamond));
        assertEq(erc721.balanceOf(user1), 0);
    }

    function test_stake_not_owner() public {
        uint256 tokenId = _mintToken(user1);
        vm.prank(user2);
        vm.expectRevert(
            abi.encodeWithSignature("TokenNotOwned(uint256)", tokenId)
        );
        stakingFacet.stake(tokenId);
    }

    function test_stake_already_staked() public {
        uint256 tokenId = _mintToken(user1);
        vm.prank(user1);
        erc721.approve(address(diamond), tokenId);
        vm.prank(user1);
        stakingFacet.stake(tokenId);

        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSignature("TokenAlreadyStaked(uint256)", tokenId)
        );
        stakingFacet.stake(tokenId);
    }

    function test_stake_emits_event() public {
        uint256 tokenId = _mintToken(user1);
        vm.prank(user1);
        erc721.approve(address(diamond), tokenId);
        vm.prank(user1);
        vm.expectEmit(true, true, false, true);
        emit StakingFacet.Staked(user1, tokenId, block.timestamp);
        stakingFacet.stake(tokenId);
    }

    function test_unstake_success() public {
        uint256 tokenId = _mintToken(user1);
        vm.prank(user1);
        erc721.approve(address(diamond), tokenId);
        vm.prank(user1);
        stakingFacet.stake(tokenId);

        vm.warp(block.timestamp + 2 days);

        vm.prank(user1);
        stakingFacet.unstake(tokenId);

        assertEq(stakingFacet.totalStaked(), 0);
        assertEq(erc721.ownerOf(tokenId), user1);
        assertEq(erc721.balanceOf(user1), 1);
    }

    function test_unstake_returns_nft() public {
        uint256 tokenId = _mintToken(user1);
        vm.prank(user1);
        erc721.approve(address(diamond), tokenId);
        vm.prank(user1);
        stakingFacet.stake(tokenId);

        vm.warp(block.timestamp + 2 days);

        vm.prank(user1);
        stakingFacet.unstake(tokenId);

        assertEq(erc721.ownerOf(tokenId), user1);
    }

    function test_unstake_min_duration_not_met() public {
        uint256 tokenId = _mintToken(user1);
        vm.prank(user1);
        erc721.approve(address(diamond), tokenId);
        vm.prank(user1);
        stakingFacet.stake(tokenId);

        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSignature("MinStakeDurationNotMet(uint256)", tokenId)
        );
        stakingFacet.unstake(tokenId);
    }

    function test_unstake_not_staked() public {
        uint256 tokenId = _mintToken(user1);
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSignature("TokenNotStaked(uint256)", tokenId)
        );
        stakingFacet.unstake(tokenId);
    }

    function test_unstake_emits_event() public {
        uint256 tokenId = _mintToken(user1);
        vm.prank(user1);
        erc721.approve(address(diamond), tokenId);
        vm.prank(user1);
        stakingFacet.stake(tokenId);

        vm.warp(block.timestamp + 2 days);

        vm.prank(user1);
        vm.expectEmit(true, true, false, true);
        emit StakingFacet.Unstaked(user1, tokenId, block.timestamp, 20 ether);
        stakingFacet.unstake(tokenId);
    }

    function test_staking_rewards_accumulate() public {
        uint256 tokenId = _mintToken(user1);
        vm.prank(user1);
        erc721.approve(address(diamond), tokenId);
        vm.prank(user1);
        stakingFacet.stake(tokenId);

        vm.warp(block.timestamp + 2 days);

        uint256 pending = stakingFacet.getPendingReward(tokenId);
        assertGt(pending, 0);
    }

    function test_staking_rewards_on_unstake() public {
        uint256 tokenId = _mintToken(user1);
        vm.prank(user1);
        erc721.approve(address(diamond), tokenId);
        vm.prank(user1);
        stakingFacet.stake(tokenId);

        vm.warp(block.timestamp + 2 days);

        vm.prank(user1);
        stakingFacet.unstake(tokenId);

        assertGt(erc20.balanceOfERC20(user1), 0);
    }

    function test_claim_rewards() public {
        uint256 tokenId = _mintToken(user1);
        vm.prank(user1);
        erc721.approve(address(diamond), tokenId);
        vm.prank(user1);
        stakingFacet.stake(tokenId);

        vm.warp(block.timestamp + 5 days);

        vm.prank(user1);
        stakingFacet.claimRewards();

        assertGt(erc20.balanceOfERC20(user1), 0);
    }

    function test_claim_rewards_emits_event() public {
        uint256 tokenId = _mintToken(user1);
        vm.prank(user1);
        erc721.approve(address(diamond), tokenId);
        vm.prank(user1);
        stakingFacet.stake(tokenId);

        vm.warp(block.timestamp + 5 days);

        vm.prank(user1);
        vm.expectEmit(true, false, false, false);
        emit StakingFacet.RewardClaimed(user1, 50 ether);
        stakingFacet.claimRewards();
    }

    function test_set_reward_rate() public {
        stakingFacet.setRewardRate(20 ether);
        assertEq(stakingFacet.rewardRate(), 20 ether);
    }

    function test_set_reward_rate_emits_event() public {
        vm.expectEmit(false, false, false, true);
        emit StakingFacet.RewardRateUpdated(10 ether, 20 ether);
        stakingFacet.setRewardRate(20 ether);
    }

    function test_set_min_stake_duration() public {
        stakingFacet.setMinStakeDuration(7 days);
        assertEq(stakingFacet.minStakeDuration(), 7 days);
    }

    function test_set_min_stake_duration_emits_event() public {
        vm.expectEmit(false, false, false, true);
        emit StakingFacet.MinStakeDurationUpdated(1 days, 7 days);
        stakingFacet.setMinStakeDuration(7 days);
    }

    function test_multiple_stakes() public {
        uint256 tokenId1 = _mintToken(user1);
        uint256 tokenId2 = _mintToken(user1);

        vm.prank(user1);
        erc721.approve(address(diamond), tokenId1);
        vm.prank(user1);
        stakingFacet.stake(tokenId1);

        vm.prank(user1);
        erc721.approve(address(diamond), tokenId2);
        vm.prank(user1);
        stakingFacet.stake(tokenId2);

        assertEq(stakingFacet.totalStaked(), 2);
    }

    function test_staking_info() public {
        uint256 tokenId = _mintToken(user1);
        vm.prank(user1);
        erc721.approve(address(diamond), tokenId);
        vm.prank(user1);
        stakingFacet.stake(tokenId);

        (address staker, uint256 timestamp, uint256 reward) = stakingFacet.getStakingInfo(tokenId);
        assertEq(staker, user1);
        assertEq(timestamp, block.timestamp);
        assertEq(reward, 0);
    }

    function test_pending_reward_zero_for_unstaked() public {
        uint256 tokenId = 1;
        assertEq(stakingFacet.getPendingReward(tokenId), 0);
    }
}
