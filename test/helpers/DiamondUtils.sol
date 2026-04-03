// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "solidity-stringutils/strings.sol";

abstract contract DiamondUtils is Test {
    using strings for *;

    function generateSelectors(
        string memory _facetName
    ) internal returns (bytes4[] memory selectors) {
        // get JSON string of contract methods
        string[] memory cmd = new string[](5);
        cmd[0] = "forge";
        cmd[1] = "inspect";
        cmd[2] = _facetName;
        cmd[3] = "methods";
        cmd[4] = "--json";
        bytes memory res = vm.ffi(cmd);
        string memory st = string(res);

        // extract function signatures and take first 4 bytes of keccak
        strings.slice memory s = st.toSlice();
        // Skip any leading logs by seeking the first JSON brace
        s.find("{".toSlice());

        strings.slice memory colon = ":".toSlice();
        strings.slice memory comma = ",".toSlice();
        strings.slice memory dbquote = '"'.toSlice();
        selectors = new bytes4[]((s.count(colon)));

        for (uint i = 0; i < selectors.length; i++) {
            s.split(dbquote); // advance to next doublequote
            // split at colon, extract string up to next doublequote for methodname
            strings.slice memory method = s.split(colon).until(dbquote);
            selectors[i] = bytes4(method.keccak());
            s.split(comma).until(dbquote); // advance s to the next comma
        }
        return selectors;
    }
}
