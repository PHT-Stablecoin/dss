pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "dss-deploy/DssDeploy.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PHTDeploy, PHTDeployResult, ProxyLike, ProxyRegistryLike, DssProxyActionsLike} from "../pht/PHTDeploy.sol";
import {PHTDeployConfig, PHTDeployCollateralConfig} from "../pht/PHTDeployConfig.sol";
import {PHTCollateralHelper} from "../pht/PHTCollateralHelper.sol";
import {ArrayHelpers} from "../pht/lib/ArrayHelpers.sol";
import {DSRoles} from "../pht/lib/Roles.sol";
import {ProxyActions} from "../pht/helpers/ProxyActions.sol";
import {PHTCollateralTestLib} from "./helpers/PHTCollateralTestLib.sol";
contract PHTDeployIntegrationTest is Test {
    using ArrayHelpers for *;

    // --- Math ---
    uint256 constant RAD = 10 ** 45;

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
        h = PHTCollateralHelper(res.collateralHelper);
    }

    function test_openLockGemAndDraw() public {
        return;
        _deploy();
        vm.startPrank(eve);
        (address join, , address token, ) = PHTCollateralTestLib.addCollateral(bytes32("PHT-NEW-ILK-0"), res, h, eve);
        // transfer some tokens to bob
        IERC20(token).transfer(bob, 1000 * 10 ** 6);
        vm.stopPrank();

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
                    bytes32("PHT-NEW-ILK"),
                    uint256(1.06e6),
                    uint256(1e18), // Drawing 1 DAI (18 decimals)
                    true
                )
            ),
            (uint256)
        );
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
