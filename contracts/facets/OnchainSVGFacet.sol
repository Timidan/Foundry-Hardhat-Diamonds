// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IOnchainSVG} from "../interfaces/IOnchainSVG.sol";
import {LibAppStorage} from "../libraries/LibAppStorage.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {SVGHelper} from "../libraries/SVGHelper.sol";

contract OnchainSVGFacet is IOnchainSVG {
    error TokenDoesNotExist(uint256 tokenId);
    error Unauthorized();
    error InvalidShape(string shape);

    event ShapeSet(uint256 indexed tokenId, string shape);
    event ColorsSet(uint256 indexed tokenId, string primary, string secondary);

    modifier onlyTokenOwner(uint256 tokenId) {
        if (LibAppStorage.nftStorage().owners[tokenId] == address(0))
            revert TokenDoesNotExist(tokenId);
        if (LibAppStorage.nftStorage().owners[tokenId] != msg.sender &&
            msg.sender != LibDiamond.contractOwner())
            revert Unauthorized();
        _;
    }

    function setTokenShape(uint256 tokenId, string calldata shape) external onlyTokenOwner(tokenId) {
        if (!_isValidShape(shape)) revert InvalidShape(shape);
        LibAppStorage.svgStorage().tokenShapes[tokenId] = shape;
        emit ShapeSet(tokenId, shape);
    }

    function setTokenColors(uint256 tokenId, string calldata primary, string calldata secondary) external onlyTokenOwner(tokenId) {
        LibAppStorage.SVGStorage storage s = LibAppStorage.svgStorage();
        s.tokenPrimaryColors[tokenId] = primary;
        s.tokenSecondaryColors[tokenId] = secondary;
        emit ColorsSet(tokenId, primary, secondary);
    }

    function tokenShape(uint256 tokenId) external view returns (string memory) {
        return LibAppStorage.svgStorage().tokenShapes[tokenId];
    }

    function tokenColors(uint256 tokenId) external view returns (string memory primary, string memory secondary) {
        LibAppStorage.SVGStorage storage s = LibAppStorage.svgStorage();
        return (s.tokenPrimaryColors[tokenId], s.tokenSecondaryColors[tokenId]);
    }

    function generateSVG(uint256 tokenId) external view returns (string memory) {
        if (LibAppStorage.nftStorage().owners[tokenId] == address(0))
            revert TokenDoesNotExist(tokenId);
        return getTokenSVG(tokenId);
    }

    function getTokenSVG(uint256 tokenId) public view returns (string memory) {
        LibAppStorage.SVGStorage storage s = LibAppStorage.svgStorage();
        string memory shape = s.tokenShapes[tokenId];
        string memory primary = s.tokenPrimaryColors[tokenId];
        string memory secondary = s.tokenSecondaryColors[tokenId];

        if (bytes(shape).length == 0) shape = "circle";
        if (bytes(primary).length == 0) primary = "#FF6B6B";
        if (bytes(secondary).length == 0) secondary = "#4ECDC4";

        string memory svgContent = SVGHelper.generateShape(shape, primary, secondary, tokenId);

        return SVGHelper.wrapSVG(
            svgContent,
            string(abi.encodePacked("Token #", _toString(tokenId)))
        );
    }

    function _isValidShape(string memory shape) internal pure returns (bool) {
        return (
            keccak256(bytes(shape)) == keccak256(bytes("circle")) ||
            keccak256(bytes(shape)) == keccak256(bytes("square")) ||
            keccak256(bytes(shape)) == keccak256(bytes("triangle")) ||
            keccak256(bytes(shape)) == keccak256(bytes("diamond")) ||
            keccak256(bytes(shape)) == keccak256(bytes("hexagon")) ||
            keccak256(bytes(shape)) == keccak256(bytes("star"))
        );
    }

    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}
