pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PHTDeploy, PHTDeployResult} from "../pht/PHTDeploy.sol";
import {PHTDeployConfig, PHTDeployCollateralConfig} from "../pht/PHTDeployConfig.sol";
import {PHTCollateralHelper} from "../pht/PHTCollateralHelper.sol";
import {ArrayHelpers} from "../pht/lib/ArrayHelpers.sol";
import {DSRoles} from "../pht/lib/Roles.sol";

contract PHTDeployTest is Test {
    using ArrayHelpers for *;

    // --- Math ---
    uint256 constant WAD = 10 ** 18;
    uint256 constant RAY = 10 ** 27;
    uint256 constant RAD = 10 ** 45;

    function test_deploy() public {
        PHTDeploy d = new PHTDeploy();

        address eve = makeAddr("eve");
        address alice = makeAddr("alice");

        PHTDeployCollateralConfig[] memory collateralConfigs = new PHTDeployCollateralConfig[](0);

        PHTDeployResult memory r = d.deploy(
            PHTDeployConfig({
                govTokenSymbol: "APC",
                dogHoleRad: 10_000_000,
                vatLineRad: 10_000_000,
                jugBase: 0.0000000006279e27, // 0.00000006279% => 2% base global fee
                authorityOwner: alice,
                authorityRootUsers: [eve].toMemoryArray(),
                collateralConfigs: collateralConfigs
            })
        );

        //@TODO assert root users and permissions
        assertTrue(DSRoles(r.authority).isUserRoot(eve), "eve should be root");
        assertFalse(DSRoles(r.authority).isUserRoot(alice), "alice should NOT be root");
        assertTrue(DSRoles(r.authority).owner() == alice, "alice should be owner");
    }
}
