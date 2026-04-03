// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./LibAppStorage.sol";

library LibMultisig {
    // Minimum signatures required for execution
    uint256 constant REQUIRED_SIGNATURES = 2;

    /// @notice Check if address is a valid multisig signer.
    function isValidSigner(address signer) internal view returns (bool) {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        return s.isSigner[signer];
    }

    /// @notice Add a signature to a pending transaction.
    /// @param txHash Hash of the transaction data.
    function addSignature(bytes32 txHash) internal {
        require(isValidSigner(msg.sender), "Not a signer");
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        require(!s.executedTxs[txHash], "Already executed");
        s.pendingTxApprovals[txHash]++;
    }

    /// @notice Check if transaction has enough signatures.
    function hasEnoughSignatures(bytes32 txHash) internal view returns (bool) {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        return s.pendingTxApprovals[txHash] >= REQUIRED_SIGNATURES;
    }

    /// @notice Execute transaction if approved.
    function executeIfApproved(bytes32 txHash, address target, bytes memory data) internal returns (bool) {
        require(hasEnoughSignatures(txHash), "Not enough signatures");
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        require(!s.executedTxs[txHash], "Already executed");
        s.executedTxs[txHash] = true;
        (bool success,) = target.delegatecall(data);
        require(success, "Execution failed");
        return true;
    }
}