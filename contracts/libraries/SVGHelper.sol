// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library SVGHelper {
    function wrapSVG(string memory content, string memory title) internal pure returns (string memory) {
        return string(
            abi.encodePacked(
                '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400">',
                '<title>', title, '</title>',
                '<rect width="400" height="400" fill="#1a1a2e"/>',
                content,
                '</svg>'
            )
        );
    }

    function generateShape(string memory shape, string memory primary, string memory secondary, uint256 tokenId) internal pure returns (string memory) {
        bytes32 seed = keccak256(abi.encodePacked(tokenId));
        uint256 x = 100 + (uint256(seed) % 200);
        uint256 y = 100 + (uint256(keccak256(abi.encodePacked(seed, "y"))) % 200);

        if (keccak256(bytes(shape)) == keccak256(bytes("circle"))) {
            return _circle(primary, secondary, x, y);
        } else if (keccak256(bytes(shape)) == keccak256(bytes("square"))) {
            return _square(primary, secondary, x, y);
        } else if (keccak256(bytes(shape)) == keccak256(bytes("triangle"))) {
            return _triangle(primary, secondary, x, y);
        } else if (keccak256(bytes(shape)) == keccak256(bytes("diamond"))) {
            return _diamond(primary, secondary, x, y);
        } else if (keccak256(bytes(shape)) == keccak256(bytes("hexagon"))) {
            return _hexagon(primary, secondary, x, y);
        } else if (keccak256(bytes(shape)) == keccak256(bytes("star"))) {
            return _star(primary, secondary, x, y);
        }
        return _circle(primary, secondary, x, y);
    }

    function _circle(string memory primary, string memory secondary, uint256 x, uint256 y) internal pure returns (string memory) {
        return string(
            abi.encodePacked(
                '<circle cx="', _uintToStr(x), '" cy="', _uintToStr(y), '" r="80" fill="', primary, '" stroke="', secondary, '" stroke-width="4"/>',
                '<circle cx="', _uintToStr(x), '" cy="', _uintToStr(y), '" r="40" fill="', secondary, '" opacity="0.5"/>'
            )
        );
    }

    function _square(string memory primary, string memory secondary, uint256 x, uint256 y) internal pure returns (string memory) {
        return string(
            abi.encodePacked(
                '<rect x="', _uintToStr(x - 60), '" y="', _uintToStr(y - 60), '" width="120" height="120" fill="', primary, '" stroke="', secondary, '" stroke-width="4" rx="8"/>',
                '<rect x="', _uintToStr(x - 30), '" y="', _uintToStr(y - 30), '" width="60" height="60" fill="', secondary, '" opacity="0.5" rx="4"/>'
            )
        );
    }

    function _triangle(string memory primary, string memory secondary, uint256 x, uint256 y) internal pure returns (string memory) {
        return string(
            abi.encodePacked(
                '<polygon points="', _uintToStr(x), ',', _uintToStr(y - 80), ' ', _uintToStr(x - 70), ',', _uintToStr(y + 60), ' ', _uintToStr(x + 70), ',', _uintToStr(y + 60), '" fill="', primary, '" stroke="', secondary, '" stroke-width="4"/>',
                '<polygon points="', _uintToStr(x), ',', _uintToStr(y - 40), ' ', _uintToStr(x - 35), ',', _uintToStr(y + 30), ' ', _uintToStr(x + 35), ',', _uintToStr(y + 30), '" fill="', secondary, '" opacity="0.5"/>'
            )
        );
    }

    function _diamond(string memory primary, string memory secondary, uint256 x, uint256 y) internal pure returns (string memory) {
        return string(
            abi.encodePacked(
                '<polygon points="', _uintToStr(x), ',', _uintToStr(y - 90), ' ', _uintToStr(x + 60), ',', _uintToStr(y), ' ', _uintToStr(x), ',', _uintToStr(y + 90), ' ', _uintToStr(x - 60), ',', _uintToStr(y), '" fill="', primary, '" stroke="', secondary, '" stroke-width="4"/>',
                '<polygon points="', _uintToStr(x), ',', _uintToStr(y - 45), ' ', _uintToStr(x + 30), ',', _uintToStr(y), ' ', _uintToStr(x), ',', _uintToStr(y + 45), ' ', _uintToStr(x - 30), ',', _uintToStr(y), '" fill="', secondary, '" opacity="0.5"/>'
            )
        );
    }

    function _hexagon(string memory primary, string memory secondary, uint256 x, uint256 y) internal pure returns (string memory) {
        return string(
            abi.encodePacked(
                '<polygon points="',
                _uintToStr(x), ',', _uintToStr(y - 70), ' ',
                _uintToStr(x + 60), ',', _uintToStr(y - 35), ' ',
                _uintToStr(x + 60), ',', _uintToStr(y + 35), ' ',
                _uintToStr(x), ',', _uintToStr(y + 70), ' ',
                _uintToStr(x - 60), ',', _uintToStr(y + 35), ' ',
                _uintToStr(x - 60), ',', _uintToStr(y - 35),
                '" fill="', primary, '" stroke="', secondary, '" stroke-width="4"/>',
                '<polygon points="',
                _uintToStr(x), ',', _uintToStr(y - 35), ' ',
                _uintToStr(x + 30), ',', _uintToStr(y - 17), ' ',
                _uintToStr(x + 30), ',', _uintToStr(y + 17), ' ',
                _uintToStr(x), ',', _uintToStr(y + 35), ' ',
                _uintToStr(x - 30), ',', _uintToStr(y + 17), ' ',
                _uintToStr(x - 30), ',', _uintToStr(y - 35),
                '" fill="', secondary, '" opacity="0.5"/>'
            )
        );
    }

    function _star(string memory primary, string memory secondary, uint256 x, uint256 y) internal pure returns (string memory) {
        return string(
            abi.encodePacked(
                '<polygon points="',
                _uintToStr(x), ',', _uintToStr(y - 80), ' ',
                _uintToStr(x + 20), ',', _uintToStr(y - 25), ' ',
                _uintToStr(x + 75), ',', _uintToStr(y - 25), ' ',
                _uintToStr(x + 30), ',', _uintToStr(y + 5), ' ',
                _uintToStr(x + 45), ',', _uintToStr(y + 60), ' ',
                _uintToStr(x), ',', _uintToStr(y + 30), ' ',
                _uintToStr(x - 45), ',', _uintToStr(y + 60), ' ',
                _uintToStr(x - 30), ',', _uintToStr(y + 5), ' ',
                _uintToStr(x - 75), ',', _uintToStr(y - 25), ' ',
                _uintToStr(x - 20), ',', _uintToStr(y - 25),
                '" fill="', primary, '" stroke="', secondary, '" stroke-width="4"/>',
                '<circle cx="', _uintToStr(x), '" cy="', _uintToStr(y), '" r="20" fill="', secondary, '" opacity="0.5"/>'
            )
        );
    }

    function _uintToStr(uint256 value) internal pure returns (string memory) {
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
