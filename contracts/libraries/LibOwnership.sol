// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { LibDiamond } from "./LibDiamond.sol";

error NotDiamondOwner();

library LibOwnership {
  bytes32 constant DIAMOND_STORAGE_POSITION =
    keccak256("diamond.standard.ownership.storage");

  struct DiamondStorage {
    // owner of the contract
    address contractOwner;
  }

  event OwnershipTransferred(
    address indexed previousOwner,
    address indexed newOwner
  );

  function diamondStorage() internal pure returns (DiamondStorage storage ds) {
    bytes32 position = DIAMOND_STORAGE_POSITION;
    assembly {
      ds.slot := position
    }
  }

  function setContractOwner(address _newOwner) internal {
    DiamondStorage storage ds = diamondStorage();
    address previousOwner = ds.contractOwner;
    ds.contractOwner = _newOwner;
    emit OwnershipTransferred(previousOwner, _newOwner);
  }

  function contractOwner() internal view returns (address contractOwner_) {
    contractOwner_ = diamondStorage().contractOwner;
  }

  function enforceIsContractOwner() internal view {
    if (msg.sender != diamondStorage().contractOwner) revert NotDiamondOwner();
  }
}
