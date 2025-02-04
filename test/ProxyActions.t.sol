pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {DssDeploy, Clipper, Spotter} from "lib/dss-cdp-manager/lib/dss-deploy/src/DssDeploy.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {DSAuth, DSAuthority} from "ds-auth/auth.sol";
import {DSPause, DSPauseProxy} from "ds-pause/pause.sol";

import {Jug} from "../src/jug.sol";
import {Vat} from "../src/vat.sol";

import {LinearDecrease} from "dss/abaci.sol";
import {GemJoin5} from "dss-gem-joins/join-5.sol";
import {GemJoin} from "dss/join.sol";

import {DSRoles} from "../pht/lib/Roles.sol";
import {PHTDeploy, PHTDeployResult} from "../script/PHTDeploy.sol";
import {PHTCollateralHelper} from "../pht/PHTCollateralHelper.sol";
import {PriceFeedFactory, PriceFeedAggregator} from "../pht/factory/PriceFeedFactory.sol";
import {PriceJoinFeedFactory, PriceJoinFeedAggregator} from "../pht/factory/PriceJoinFeedFactory.sol";
import {ChainlinkPip, AggregatorV3Interface, PipLike} from "../pht/helpers/ChainlinkPip.sol";
import {IlkRegistry} from "dss-ilk-registry/IlkRegistry.sol";
import {ProxyActions, DelayedAction} from "../pht/helpers/ProxyActions.sol";

import {PHTDeployConfig} from "../script/PHTDeployConfig.sol";
import {ArrayHelpers} from "../pht/lib/ArrayHelpers.sol";

import {PHTCollateralTestLib} from "./helpers/PHTCollateralTestLib.sol";

contract ProxyActionsTest is Test {
    using ArrayHelpers for *;

    // --- Math ---
    uint256 constant WAD = 10 ** 18;
    uint256 constant RAY = 10 ** 27;
    uint256 constant RAD = 10 ** 45;

    // --- CONSTANTS ---
    string constant ILK_PREFIX = "PHT-NEW-ILK-";

    // -- ROLES --
    uint8 constant ROLE_GOV_MINT_BURN = 10;
    uint8 constant ROLE_CAN_PLOT = 11;

    address alice; // authority owner
    address eve; // authority root user
    PHTDeployResult res;
    PHTCollateralHelper h;

    function setUp() public {
        eve = makeAddr("eve");
        alice = makeAddr("alice");
        PHTDeploy d = new PHTDeploy();
        res = d.deploy(
            PHTDeployConfig({
                govTokenSymbol: "APX",
                phtUsdFeed: address(0), // deploy a mock feed for testing
                dogHoleRad: 10_000_000,
                vatLineRad: 10_000_000,
                jugBase: 0.0000000006279e27, // 0.00000006279% => 2% base global fee
                authorityOwner: alice,
                authorityRootUsers: [eve].toMemoryArray(),
                vowWaitSeconds: uint256(0),
                vowDumpWad: uint256(0),
                vowSumpRad: uint256(0),
                vowBumpRad: uint256(0),
                vowHumpRad: uint256(0)
            })
        );
        h = PHTCollateralHelper(res.collateralHelper);
    }

    function test_delay_with_zero_and_file() public {
        // Must call setDelay(...) from an authorized user:
        vm.startPrank(eve);
        DelayedAction memory a = ProxyActions(res.proxyActions).file(res.vat, "Line", 999);
        assertEq(a.eta, now);
        assertEq(Vat(res.vat).Line(), 999);
    }

    function test_setDelay_and_file() public {
        // Must call setDelay(...) from an authorized user:
        vm.startPrank(eve);
        ProxyActions(res.proxyActions).setDelay(1 hours);

        DelayedAction memory a = ProxyActions(res.proxyActions).file(res.vat, "Line", 999);
        assertNotEq(Vat(res.vat).Line(), 999);

        skip(1 hours);

        DSPause(res.pause).exec(a.usr, a.tag, a.fax, a.eta);
        assertEq(Vat(res.vat).Line(), 999);
    }

    function test_auth_fail() public {
        address dog = res.dog;
        address randomUser = makeAddr("random");
        address pauseProxy = address(DSPause(res.pause).proxy());

        // randomUser -> rely(...) should fail (not auth)
        vm.startPrank(randomUser);
        vm.expectRevert("ds-auth-unauthorized");
        ProxyActions(res.proxyActions).rely(dog, randomUser);

        vm.expectRevert("ds-auth-unauthorized");
        ProxyActions(res.proxyActions).deny(dog, randomUser);

        vm.expectRevert("ds-auth-unauthorized");
        ProxyActions(res.proxyActions).init(dog, "");

        vm.expectRevert("ds-auth-unauthorized");
        ProxyActions(res.proxyActions).file(dog, "", uint256(0));

        vm.expectRevert("ds-auth-unauthorized");
        ProxyActions(res.proxyActions).file(dog, "", address(0));

        vm.expectRevert("ds-auth-unauthorized");
        ProxyActions(res.proxyActions).file(dog, "", "", address(0));

        vm.expectRevert("ds-auth-unauthorized");
        ProxyActions(res.proxyActions).file(dog, "", "", uint256(0));

        vm.expectRevert("ds-auth-unauthorized");
        ProxyActions(res.proxyActions).dripAndFile(dog, "", uint256(0));

        vm.expectRevert("ds-auth-unauthorized");
        ProxyActions(res.proxyActions).dripAndFile(dog, "", "", uint256(0));

        vm.expectRevert("ds-auth-unauthorized");
        ProxyActions(res.proxyActions).cage(dog);

        vm.expectRevert("ds-auth-unauthorized");
        ProxyActions(res.proxyActions).setAuthority2(dog);

        vm.expectRevert("ds-auth-unauthorized");
        ProxyActions(res.proxyActions).setDelay(uint256(0));

        vm.expectRevert("ds-auth-unauthorized");
        ProxyActions(res.proxyActions).setAuthorityAndDelay(dog, uint256(0));
    }
}
