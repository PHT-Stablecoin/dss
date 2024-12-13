pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "dss-deploy/DssDeploy.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PHTDeploy, PHTDeployResult} from "../pht/PHTDeploy.sol";
import {PHTDeployConfig, PHTDeployCollateralConfig} from "../pht/PHTDeployConfig.sol";
import {PHTCollateralHelper} from "../pht/PHTCollateralHelper.sol";
import {ArrayHelpers} from "../pht/lib/ArrayHelpers.sol";
import {DSRoles} from "../pht/lib/Roles.sol";
// import {Dog} from "../src/dog.sol";
import {DssProxy} from "../pht/lib/DssProxy.sol";
contract PHTDeployTest is Test {
    using ArrayHelpers for *;

    // --- Math ---
    uint256 constant WAD = 10 ** 18;
    uint256 constant RAY = 10 ** 27;
    uint256 constant RAD = 10 ** 45;

    address alice; // authority owner
    address eve; // authority root user
    PHTDeploy d;
    PHTDeployResult res;

    function _deploy() internal {
        d = new PHTDeploy();
        eve = makeAddr("eve");
        alice = makeAddr("alice");

        PHTDeployCollateralConfig[] memory collateralConfigs = new PHTDeployCollateralConfig[](0);

        res = d.deploy(
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
    }

    function test_deploy() public {
        _deploy();

        assertTrue(DSRoles(res.authority).isUserRoot(eve), "eve should be root");
        assertFalse(DSRoles(res.authority).isUserRoot(alice), "alice should NOT be root");
        assertTrue(DSRoles(res.authority).owner() == alice, "alice should be owner");
    }

    function test_openLockGemAndDraw() public {
        _deploy();
        vm.startPrank(eve);
        vm.expectRevert("Dog/not-authorized");
        Dog(res.dog).file("Hole", 10_000_000 * RAD); // Set global limit to 10 million DAI (RAD units)

        uint256 currentHole = Dog(res.dog).Hole();
        console.log("currentHole", currentHole);
        uint256 newHole = currentHole + 10_000_000 * RAD;

        bytes4 selectorDogFile = bytes4(keccak256("file(bytes32,uint256)"));

        DssProxy(payable(res.dssProxy)).execute(
            address(res.dog),
            abi.encodeWithSelector(selectorDogFile, "Hole", newHole)
        );

        assertEq(Dog(res.dog).Hole(), newHole, "Hole should be set to new value");
        vm.stopPrank();
    }
}
