// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LibAppStorage} from "../libraries/LibAppStorage.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";

contract NFTAdminFacet {
    function setMintActive(bool active) external {
        LibDiamond.enforceIsContractOwner();
        LibAppStorage.nftStorage().mintActive = active;
    }

    function setMintPrice(uint256 price) external {
        LibDiamond.enforceIsContractOwner();
        LibAppStorage.nftStorage().mintPrice = price;
    }

    function setBaseTokenURI(string calldata uri) external {
        LibDiamond.enforceIsContractOwner();
        LibAppStorage.nftStorage().baseTokenURI = uri;
    }

    function setMaxSupply(uint256 supply) external {
        LibDiamond.enforceIsContractOwner();
        LibAppStorage.nftStorage().maxSupply = supply;
    }

    function withdraw() external {
        LibDiamond.enforceIsContractOwner();
        (bool success, ) = LibDiamond.contractOwner().call{value: address(this).balance}("");
        require(success, "Withdraw failed");
    }
}
