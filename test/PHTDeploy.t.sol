pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "dss-deploy/DssDeploy.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PHTDeploy, PHTDeployResult} from "../script/PHTDeploy.sol";
import {PHTDeployConfig} from "../script/PHTDeployConfig.sol";
import {PHTCollateralHelper} from "../pht/PHTCollateralHelper.sol";
import {ArrayHelpers} from "../pht/lib/ArrayHelpers.sol";
import {DSRoles} from "../pht/lib/Roles.sol";
import {ProxyActions} from "../pht/helpers/ProxyActions.sol";
import {Vow} from "dss/vow.sol";

contract PHTDeployTest is Test {
    using ArrayHelpers for *;

    // --- Math ---
    uint256 constant RAD = 10 ** 45;

    address alice; // authority owner
    address eve; // authority root user
    PHTDeploy d;
    PHTDeployResult res;

    function _deploy() internal {
        d = new PHTDeploy();
        eve = makeAddr("eve");
        alice = makeAddr("alice");

        res = d.deploy(
            PHTDeployConfig({
                govTokenName: "APACX Governance Token",
                govTokenSymbol: "APCX",
                phtUsdFeed: address(0), // deploy a mock feed for testing
                dogHoleRad: 10_000_000,
                vatLineRad: 10_000_000,
                jugBase: 0.0000000006279e27, // 0.00000006279% => 2% base global fee
                authorityOwner: alice,
                authorityRootUsers: [eve].toMemoryArray(),
                vowWaitSeconds: uint256(133),
                vowDumpWad: uint256(133),
                vowSumpRad: uint256(133),
                vowBumpRad: uint256(133),
                vowHumpRad: uint256(133)
            })
        );
    }

    function test_deploy() public {
        _deploy();

        assertTrue(DSRoles(res.authority).isUserRoot(eve), "eve should be root");
        assertFalse(DSRoles(res.authority).isUserRoot(alice), "alice should NOT be root");
        assertTrue(DSRoles(res.authority).owner() == alice, "alice should be owner");
        assertEq(Vow(res.vow).wait(), 133, "vow.wait should be set");
        assertEq(Vow(res.vow).dump(), 133, "vow.dump should be set");
        assertEq(Vow(res.vow).sump(), 133, "vow.sump should be set");
        assertEq(Vow(res.vow).bump(), 133, "vow.bump should be set");
        assertEq(Vow(res.vow).hump(), 133, "vow.hump should be set");
    }

    function test_openLockGemAndDraw() public {
        _deploy();
        vm.startPrank(eve);
        vm.expectRevert("Dog/not-authorized");
        Dog(res.dog).file("Hole", 10_000_000 * RAD); // Set global limit to 10 million DAI (RAD units)

        uint256 currentHole = Dog(res.dog).Hole();
        uint256 newHole = currentHole + 10_000_000 * RAD;

        ProxyActions(res.proxyActions).file(res.dog, "Hole", newHole);

        assertEq(Dog(res.dog).Hole(), newHole, "Hole should be set to new value");
        vm.stopPrank();
    }
}

interface DsPauseLike {
    function plot(address, bytes32, bytes calldata, uint256) external;
    function drop(address, bytes32, bytes calldata, uint256) external;
    function exec(address, bytes32, bytes calldata, uint256) external returns (bytes memory);
}

interface IHasWards {
    function wards(address) external view returns (uint256);
}

interface IHasProxy {
    function proxy() external view returns (address);
}
