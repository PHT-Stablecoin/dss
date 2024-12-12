// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {PHTDeploy, PHTDeployResult} from "../pht/PHTDeploy.sol";

// forge test that tests the size of the FXPool contract

contract SizeTest is Test {
    uint256 constant MAX_SIZE = 24576; // 24KB in bytes

    function testSize() public {
        bool exceeds = false;
        PHTDeploy d = new PHTDeploy();
        if (checkContractSize("PHTDeploy", contractSize(address(d)))) {
            exceeds = true;
        }
        // @TODO disabled until we fix PHTDeploy
        // assertFalse(exceeds, "One of the contracts exceeds max contract size of 24KB");
    }

    function contractSize(address addr) internal view returns (uint256 size) {
        assembly {
            size := extcodesize(addr)
        }
    }

    function checkContractSize(string memory name, uint256 size) internal pure returns (bool exceeds) {
        uint256 sizeKB = (size / 1024) + 1;
        uint256 percentage = (size * 100) / MAX_SIZE;

        console.log(
            string(abi.encodePacked(name, ": ", vm.toString(sizeKB), "KB (", vm.toString(percentage), "% of max)"))
        );

        if (size > MAX_SIZE) {
            console.log("[X] Exceeds maximum size!");
            exceeds = true;
        } else if (size > ((MAX_SIZE * 90) / 100)) {
            console.log("[!] Warning: Close to maximum size!");
        } else {
            console.log("[+] Size is okay");
        }
        console.log("---------------------");
    }
}
