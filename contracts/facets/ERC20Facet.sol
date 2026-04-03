// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IERC20.sol";
import "../libraries/LibAppStorage.sol";

contract ERC20Facet is IERC20 {
    /// @notice Get total supply.
    function totalSupply() external view returns (uint256) {
        return LibAppStorage.appStorage().erc20TotalSupply;
    }

    /// @notice Get balance of account.
    function balanceOf(address account) external view returns (uint256) {
        return LibAppStorage.appStorage().erc20Balances[account];
    }

    /// @notice Transfer tokens.
    function transfer(address to, uint256 amount) external returns (bool) {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        require(s.erc20Balances[msg.sender] >= amount, "Insufficient balance");
        s.erc20Balances[msg.sender] -= amount;
        s.erc20Balances[to] += amount;
        return true;
    }

    /// @notice Get allowance.
    function allowance(address owner, address spender) external view returns (uint256) {
        return LibAppStorage.appStorage().erc20Allowances[owner][spender];
    }

    /// @notice Approve spender.
    function approve(address spender, uint256 amount) external returns (bool) {
        LibAppStorage.appStorage().erc20Allowances[msg.sender][spender] = amount;
        return true;
    }

    /// @notice Transfer from.
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        require(s.erc20Balances[from] >= amount, "Insufficient balance");
        require(s.erc20Allowances[from][msg.sender] >= amount, "Insufficient allowance");
        s.erc20Balances[from] -= amount;
        s.erc20Balances[to] += amount;
        s.erc20Allowances[from][msg.sender] -= amount;
        return true;
    }

    /// @notice Mint tokens (for testing).
    function mint(address to, uint256 amount) external {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        s.erc20Balances[to] += amount;
        s.erc20TotalSupply += amount;
    }

    /// @notice Get token name.
    function name() external pure returns (string memory) {
        return "DiamondToken";
    }

    /// @notice Set balance for testing (only for test environments).
    function setBalance(address account, uint256 amount) external {
        LibAppStorage.appStorage().erc20Balances[account] = amount;
    }
}