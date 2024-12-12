pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import {StdCheatsSafe} from "forge-std/StdCheats.sol";
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {Jug} from "../src/jug.sol";

contract TestFailedTx is StdCheatsSafe, Test {
    function test_failed_tx() public {
        // vm.createSelectFork("http://127.0.0.1:8545");
        vm.createSelectFork("https://eth-sepolia.g.alchemy.com/v2/U7tte8molsSlREKDCvXxIXR1OBmyKRhp", 7221732);

        uint256 basePctPerSecond = (uint256(2) * uint256(10 ** 27)) / 31536000;
        uint256 dutyPctPerSecond = (uint256(4) * uint256(10 ** 27)) / 31536000;
        console.log("basePctPerSecond", basePctPerSecond);
        console.log("dutyPctPerSecond", dutyPctPerSecond);

        address vat = 0x9d6F21d8Ce87B756C18692f9C286E610f50f9FB0;
        address deployedJug = 0x99e895C6Ff5e47C6b8FF7E428d8488D09A5b7e49;
        bytes32 ilk = 0x555344542d410000000000000000000000000000000000000000000000000000;

        // vm.startPrank(0x0a23f980D752eC87fC0B7Ce32D93C952eEFf6953);
        // IJug(deployedJug).file("base", basePctPerSecond);
        // IJug(deployedJug).file(ilk, "duty", dutyPctPerSecond);
        // vm.stopPrank();

        Jug jug = new Jug(vat);
        bytes memory code;
        assembly {
            let size := extcodesize(jug)
            code := mload(0x40)
            mstore(0x40, add(code, and(add(add(size, 0x20), 0x1f), not(0x1f))))
            mstore(code, size)
            extcodecopy(jug, add(code, 0x20), 0, size)
        }

        vm.etch(deployedJug, code);

        uint256 rate = IJug(deployedJug).drip(ilk);
        console.log("rate", rate);
    }
}

interface IJug {
    function drip(bytes32 ilk) external returns (uint rate);
    function file(bytes32 ilk, bytes32 what, uint data) external;
    function file(bytes32 what, uint data) external;
    function file(bytes32 what, address data) external;
}

interface IVat {
    function file(bytes32 ilk, bytes32 what, uint data) external;
}
