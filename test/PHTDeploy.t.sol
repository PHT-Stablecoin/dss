pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PHTDeploy} from "../pht/PHTDeploy.sol";
import {PHTDeployConfig} from "../pht/PHTDeployConfig.sol";
import {ArrayHelpers} from "../pht/lib/ArrayHelpers.sol";

contract PHTDeployTest is Test {
    using ArrayHelpers for *;

    // --- Math ---
    uint256 constant WAD = 10 ** 18;
    uint256 constant RAY = 10 ** 27;
    uint256 constant RAD = 10 ** 45;

    function test_deploy() public {
        address eve = makeAddr("eve");
        PHTDeploy d = new PHTDeploy();
        d.deploy(
            PHTDeployConfig({
                govTokenSymbol: "APC",
                dogHoleRad: 10_000_000,
                vatLineRad: 10_000_000,
                jugBase: 0.0000000006279e27, // 0.00000006279% => 2% base global fee
                rootUsers: [eve].toMemoryArray()
            })
        );

        //@TODO assert root users and permissions
    }
}
