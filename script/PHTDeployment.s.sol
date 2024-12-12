pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import {PHTDeploy, PHTDeployResult} from "../pht/PHTDeploy.sol";
import {PHTDeployConfig, PHTDeployCollateralConfig} from "../pht/PHTDeployConfig.sol";
import {DSRoles} from "../pht/lib/Roles.sol";
import {ArrayHelpers} from "../pht/lib/ArrayHelpers.sol";

contract PHTDeploymentScript is Script, PHTDeploy, Test {
    using ArrayHelpers for *;
    function run() public {
        vm.startBroadcast();
        PHTDeployCollateralConfig[] memory collateralConfigs = new PHTDeployCollateralConfig[](0);
        PHTDeployResult memory r = this.deploy(
            PHTDeployConfig({
                govTokenSymbol: "APC",
                dogHoleRad: 10_000_000,
                vatLineRad: 10_000_000,
                jugBase: 0.0000000006279e27, // 0.00000006279% => 2% base global fee
                rootUsers: [msg.sender].toMemoryArray(),
                collateralConfigs: collateralConfigs
            })
        );
        vm.stopBroadcast();

        assertTrue(DSRoles(r.authority).isUserRoot(msg.sender), "msg.sender is root");
    }
}
