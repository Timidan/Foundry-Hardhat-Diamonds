// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMultisig {
    function addSigner(address signer) external;
    function removeSigner(address signer) external;
    function signTransaction(bytes32 txHash) external;
    function executeTransaction(bytes32 txHash, address target, bytes calldata data) external;
}