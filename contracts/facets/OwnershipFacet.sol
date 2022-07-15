// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IERC173 } from "../interfaces/IERC173.sol";
import { LibOwnership } from "../libraries/LibOwnership.sol";

abstract contract OwnershipModifers {
  modifier onlyOwner() {
    require(
      msg.sender == LibOwnership.contractOwner(),
      "Only the contract owner can call this function"
    );
    _;
  }
}

contract OwnershipFacet is IERC173, OwnershipModifers {
  function transferOwnership(address _newOwner) external override {
    LibOwnership.enforceIsContractOwner();
    LibOwnership.setContractOwner(_newOwner);
  }

  function owner() external view override returns (address owner_) {
    owner_ = LibOwnership.contractOwner();
  }
}
