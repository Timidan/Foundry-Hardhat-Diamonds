// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function totalSupplyERC20() external view returns (uint256);
    function balanceOfERC20(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approveERC20(address spender, uint256 amount) external returns (bool);
    function transferFromERC20(address from, address to, uint256 amount) external returns (bool);
}

interface IERC20Metadata is IERC20 {
    function nameERC20() external view returns (string memory);
    function symbolERC20() external view returns (string memory);
    function decimalsERC20() external view returns (uint8);
}
