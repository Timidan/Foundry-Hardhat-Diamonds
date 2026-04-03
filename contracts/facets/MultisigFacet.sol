// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IMultisig.sol";
import "../libraries/LibAppStorage.sol";
import "../libraries/LibMultisig.sol";

contract MultisigFacet is IMultisig {
    /// @notice Add a signer (multisig protected).
    function addSigner(address signer) external {
        bytes32 txHash = keccak256(abi.encodePacked("addSigner", signer));
        LibMultisig.addSignature(txHash);
        if (LibMultisig.hasEnoughSignatures(txHash)) {
            LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
            s.isSigner[signer] = true;
            s.multisigSigners.push(signer);
            s.executedTxs[txHash] = true; // Mark as executed
        }
    }

    /// @notice Remove a signer.
    function removeSigner(address signer) external {
        bytes32 txHash = keccak256(abi.encodePacked("removeSigner", signer));
        LibMultisig.addSignature(txHash);
        if (LibMultisig.hasEnoughSignatures(txHash)) {
            LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
            s.isSigner[signer] = false;
            // Remove from array (simplified)
            s.executedTxs[txHash] = true; // Mark as executed
        }
    }

    /// @notice Sign a transaction.
    function signTransaction(bytes32 txHash) external {
        LibMultisig.addSignature(txHash);
    }

    /// @notice Execute a transaction if approved.
    function executeTransaction(bytes32 txHash, address target, bytes calldata data) external {
        LibMultisig.executeIfApproved(txHash, target, data);
    }
}