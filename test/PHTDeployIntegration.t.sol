pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "dss-deploy/DssDeploy.sol";
import {DssCdpManager} from "dss-cdp-manager/DssCdpManager.sol";
import {Vat} from "../src/vat.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {PHTDeploy, PHTDeployResult, ProxyLike, ProxyRegistryLike, DssProxyActionsLike} from "../pht/PHTDeploy.sol";
import {Jug} from "../src/jug.sol";
import {PHTDeployConfig} from "../pht/PHTDeployConfig.sol";
import {PHTCollateralHelper} from "../pht/PHTCollateralHelper.sol";
import {ArrayHelpers} from "../pht/lib/ArrayHelpers.sol";
import {DSRoles} from "../pht/lib/Roles.sol";
import {ProxyActions} from "../pht/helpers/ProxyActions.sol";
import {PHTCollateralTestLib} from "./helpers/PHTCollateralTestLib.sol";
contract PHTDeployIntegrationTest is Test {
    using ArrayHelpers for *;

    // --- Math ---
    uint256 constant RAD = 10 ** 45;

    // --- Constants ---
    bytes32 constant ILK_NAME = bytes32("PHT-NEW-ILK-0");

    address alice; // authority owner
    address eve; // authority root user
    address bob; // normal non-admin / "normal" user

    PHTDeploy d;
    PHTDeployResult res;
    PHTCollateralHelper h;
    function _deploy() internal {
        d = new PHTDeploy();
        eve = makeAddr("eve");
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        res = d.deploy(
            PHTDeployConfig({
                govTokenSymbol: "APC",
                dogHoleRad: 10_000_000,
                vatLineRad: 10_000_000,
                jugBase: 0.0000000006279e27, // 0.00000006279% => 2% base global fee
                authorityOwner: alice,
                authorityRootUsers: [eve].toMemoryArray()
            })
        );
        h = PHTCollateralHelper(res.collateralHelper);
    }

    function test_openLockGemAndDraw() public {
        _deploy();
        vm.startPrank(eve);
        (address join, , address token, ) = PHTCollateralTestLib.addCollateral(bytes32(ILK_NAME), res, h, eve);

        // transfer some tokens to bob
        IERC20(token).transfer(bob, 1000 * 10 ** 6);
        vm.stopPrank();

        {
            // Move Blocktime to 10 blocks ahead
            vm.warp(now + 100);

            uint256 jugBase = Jug(res.jug).base();
            uint256 jugRate = Jug(res.jug).drip(ILK_NAME);
            assertGt(jugBase, 0, "jugBase is not zero");
            assertGt(jugRate, 0, "jugRate is not zero");
        }

        // normal user opens a CDP
        vm.startPrank(bob);
        address proxy = ProxyRegistryLike(res.dssProxyRegistry).build(bob);
        assertEq(ProxyLike(proxy).owner(), bob, "bob is the proxy owner");
        // bob approves the proxy to spend his tokens
        IERC20(token).approve(address(proxy), 1000 * 10 ** 6);
        // Call openLockGemAndDraw with correct amtC
        uint256 cdpId = abi.decode(
            ProxyLike(proxy).execute(
                address(res.dssProxyActions),
                abi.encodeWithSelector(
                    DssProxyActionsLike.openLockGemAndDraw.selector,
                    res.dssCdpManager,
                    res.jug,
                    join,
                    res.daiJoin,
                    ILK_NAME,
                    uint256(1.06e6),
                    uint256(1e18), // Drawing 1 DAI (18 decimals)
                    true
                )
            ),
            (uint256)
        );
        vm.stopPrank();

        // Collateral owned by Join
        assertEq(IERC20(token).balanceOf(address(join)), 1.06e6, "Collateral owned by Join");
        // After operation, balance should be zero
        assertEq(Vat(res.vat).gem(ILK_NAME, address(proxy)), 0, "After operation, balance should be zero");
        // Collateral owned by cdpId also zero
        assertEq(
            Vat(res.vat).gem(ILK_NAME, DssCdpManager(res.dssCdpManager).urns(cdpId)),
            0,
            "Collateral owned by cdpId also zero"
        );

        assertEq(IERC20(res.dai).balanceOf(bob), 1e18, "Dai (PHT) is transferred to bob");
        // Gem ownership in urnhandler
        assertEq(Vat(res.vat).gem(ILK_NAME, address(this)), 0, "Gem ownership in urnhandler");
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
