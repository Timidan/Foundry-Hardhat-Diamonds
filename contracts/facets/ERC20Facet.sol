// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20, IERC20Metadata} from "../interfaces/IERC20.sol";
import {LibAppStorage} from "../libraries/LibAppStorage.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";

contract ERC20Facet is IERC20, IERC20Metadata {
    error ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed);
    error ERC20InvalidSender(address sender);
    error ERC20InvalidReceiver(address receiver);
    error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);
    error ERC20InvalidSpender(address spender);
    error ERC20ExceedsMaxSupply(uint256 amount, uint256 maxSupply);

    function totalSupplyERC20() external view returns (uint256) {
        return LibAppStorage.erc20Storage().erc20TotalSupply;
    }

    function balanceOfERC20(address account) external view returns (uint256) {
        return LibAppStorage.erc20Storage().erc20Balances[account];
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function allowance(address owner, address spender) external view returns (uint256) {
        return LibAppStorage.erc20Storage().erc20Allowances[owner][spender];
    }

    function approveERC20(address spender, uint256 amount) external returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFromERC20(address from, address to, uint256 amount) external returns (bool) {
        _spendAllowance(from, msg.sender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function nameERC20() external view returns (string memory) {
        return LibAppStorage.erc20Storage().erc20Name;
    }

    function symbolERC20() external view returns (string memory) {
        return LibAppStorage.erc20Storage().erc20Symbol;
    }

    function decimalsERC20() external view returns (uint8) {
        return LibAppStorage.erc20Storage().erc20Decimals;
    }

    function mintERC20(address to, uint256 amount) external {
        LibDiamond.enforceIsContractOwner();
        if (to == address(0)) revert ERC20InvalidReceiver(address(0));

        LibAppStorage.ERC20Storage storage s = LibAppStorage.erc20Storage();
        if (s.erc20TotalSupply + amount > s.erc20MaxSupply)
            revert ERC20ExceedsMaxSupply(amount, s.erc20MaxSupply);

        s.erc20Balances[to] += amount;
        s.erc20TotalSupply += amount;
        emit Transfer(address(0), to, amount);
    }

    function burnERC20(address from, uint256 amount) external {
        LibDiamond.enforceIsContractOwner();
        _burn(from, amount);
    }

    function burnERC20() external {
        _burn(msg.sender, LibAppStorage.erc20Storage().erc20Balances[msg.sender]);
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (from == address(0)) revert ERC20InvalidSender(address(0));
        if (to == address(0)) revert ERC20InvalidReceiver(address(0));

        LibAppStorage.ERC20Storage storage s = LibAppStorage.erc20Storage();
        uint256 fromBalance = s.erc20Balances[from];
        if (fromBalance < amount)
            revert ERC20InsufficientBalance(from, fromBalance, amount);

        s.erc20Balances[from] = fromBalance - amount;
        s.erc20Balances[to] += amount;
        emit Transfer(from, to, amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        if (owner == address(0)) revert ERC20InvalidSender(address(0));
        if (spender == address(0)) revert ERC20InvalidSpender(address(0));

        LibAppStorage.erc20Storage().erc20Allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _spendAllowance(address owner, address spender, uint256 amount) internal {
        uint256 currentAllowance = LibAppStorage.erc20Storage().erc20Allowances[owner][spender];
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < amount)
                revert ERC20InsufficientAllowance(spender, currentAllowance, amount);
            LibAppStorage.erc20Storage().erc20Allowances[owner][spender] = currentAllowance - amount;
        }
    }

    function _burn(address from, uint256 amount) internal {
        if (from == address(0)) revert ERC20InvalidSender(address(0));

        LibAppStorage.ERC20Storage storage s = LibAppStorage.erc20Storage();
        uint256 fromBalance = s.erc20Balances[from];
        if (fromBalance < amount)
            revert ERC20InsufficientBalance(from, fromBalance, amount);

        s.erc20Balances[from] = fromBalance - amount;
        s.erc20TotalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }
}
