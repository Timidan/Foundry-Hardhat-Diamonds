// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library LibSVG {
    /// @notice Generate a simple on-chain SVG for an NFT.
    /// @param tokenId The NFT ID to generate SVG for.
    /// @param name The NFT name.
    /// @param symbol The NFT symbol.
    function generateSVG(uint256 tokenId, string memory name, string memory symbol) internal pure returns (string memory) {
        return string(abi.encodePacked(
            '<svg xmlns="http://www.w3.org/2000/svg" width="300" height="300">',
            '<rect width="300" height="300" fill="blue"/>',
            '<text x="50%" y="50%" dominant-baseline="middle" text-anchor="middle" fill="white" font-size="24">',
            name, ' #', uint2str(tokenId), ' (', symbol, ')',
            '</text>',
            '</svg>'
        ));
    }

    /// @notice Convert uint256 to string.
    function uint2str(uint256 _i) internal pure returns (string memory) {
        if (_i == 0) return "0";
        uint256 j = _i;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len;
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }
}