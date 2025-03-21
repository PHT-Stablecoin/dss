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
import {ProxyActions} from "../pht/helpers/ProxyActions.sol";

import {PHTDeployConfig} from "../script/PHTDeployConfig.sol";
import {ArrayHelpers} from "../pht/lib/ArrayHelpers.sol";
import {PHTTokenHelper, TokenActions, TokenInfo} from "../pht/PHTTokenHelper.sol";

import {PHTCollateralTestLib} from "./helpers/PHTCollateralTestLib.sol";

contract PHTCollateralHelperTest is Test {
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
                govTokenName: "APACX Governance Token",
                govTokenSymbol: "APCX",
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
        // allow this contract to create feeds through the feed factory
        // we do this in the test helper PHTCollateralTestLib.addCollateralJoin
        vm.startPrank(alice);
        DSRoles(address(res.authority)).setUserRole(address(this), d.ROLE_FEED_FACTORY_CREATE(), true);
        vm.stopPrank();
    }

    function geLastIlkName(address ilkRegistry) internal view returns (bytes32) {
        return keccak256(abi.encodePacked(ILK_PREFIX, IlkRegistry(ilkRegistry).count() - 1));
    }

    function getNextIlkName(address ilkRegistry) internal view returns (bytes32) {
        return keccak256(abi.encodePacked(ILK_PREFIX, IlkRegistry(ilkRegistry).count()));
    }

    function test_multipleIlks() public {
        bytes32 prevIlk;
        uint256 prevIlkDuty;
        vm.startPrank(eve);
        PHTCollateralTestLib.addCollateral(getNextIlkName(res.ilkRegistry), res, h, eve);
        prevIlk = geLastIlkName(res.ilkRegistry);
        (prevIlkDuty,) = Jug(res.jug).ilks(prevIlk);
        assertGt(prevIlkDuty, 0, "prev ilk duty should not be zero");
        assertTrue(prevIlk != getNextIlkName(res.ilkRegistry), "prev ilk should not be the same as the next ilk");

        PHTCollateralTestLib.addCollateral(getNextIlkName(res.ilkRegistry), res, h, eve);
        prevIlk = geLastIlkName(res.ilkRegistry);
        (prevIlkDuty,) = Jug(res.jug).ilks(prevIlk);
        assertGt(prevIlkDuty, 0, "prev ilk duty should not be zero");

        PHTCollateralTestLib.addCollateral(getNextIlkName(res.ilkRegistry), res, h, eve);
        PHTCollateralTestLib.addCollateral(getNextIlkName(res.ilkRegistry), res, h, eve);
        vm.stopPrank();

        assertEq(
            getNextIlkName(res.ilkRegistry),
            keccak256(abi.encodePacked(ILK_PREFIX, uint256(4))),
            "ilk name correct for multiple adds"
        );
    }

    function test_addsIlk() public {
        uint256 ilksCountBef = IlkRegistry(res.ilkRegistry).count();

        vm.startPrank(eve);
        bytes32 ilk = getNextIlkName(res.ilkRegistry);
        (
            address phpJoin,
            AggregatorV3Interface feed,
            address token,
            ChainlinkPip pip,
            PHTCollateralHelper.IlkParams memory ilkParams,
            PHTCollateralHelper.TokenParams memory tokenParams,
            PHTCollateralHelper.FeedParams memory feedParams
        ) = PHTCollateralTestLib.addCollateral(ilk, res, h, eve);
        vm.stopPrank();

        assertEq(IERC20Metadata(token).name(), "Test PHP", "token name");
        assertEq(IERC20Metadata(token).symbol(), "tstPHP", "token symbol");
        assertEq(uint256(IERC20Metadata(token).decimals()), 6, "token decimals");

        // ensure eve received the token balance
        assertEq(IERC20(token).balanceOf(eve), tokenParams.initialSupply, "eve should have received the token balance");
        assertEq(IlkRegistry(res.ilkRegistry).count(), ilksCountBef + 1, "[PHTCollateralHelperTest] ilksCount");
        assertEq(address(pip), IlkRegistry(res.ilkRegistry).pip(ilk), "Same Pip");

        Clipper ilkClip = Clipper(IlkRegistry(res.ilkRegistry).xlip(ilk));
        assertEq(ilkClip.buf(), ilkParams.buf);
        assertEq(ilkClip.tail(), ilkParams.tail);
        assertEq(ilkClip.cusp(), ilkParams.cusp);
        assertEq(uint256(ilkClip.chip()), uint256(ilkParams.chip));
        assertEq(uint256(ilkClip.tip()), uint256(ilkParams.tip));
        assertEq(ilkClip.chost(), ilkParams.dust * ilkParams.chop);

        // ensure pause.proxy auth
        DSPauseProxy proxy = DSPause(res.pause).proxy();

        vm.startPrank(eve);
        ProxyActions(res.proxyActions).rely(phpJoin, alice);
        assertEq(GemJoin(phpJoin).wards(address(proxy)), 1);
        assertEq(GemJoin(phpJoin).wards(alice), 1);
        assertEq(LinearDecrease(address(ilkClip.calc())).wards(address(proxy)), 1);
    }

    function test_addsIlk_join() public {
        uint256 ilksCountBef = IlkRegistry(res.ilkRegistry).count();

        vm.startPrank(eve);
        bytes32 ilk = getNextIlkName(res.ilkRegistry);
        (
            address phpJoin,
            AggregatorV3Interface feed,
            address token,
            ChainlinkPip pip,
            PHTCollateralHelper.IlkParams memory ilkParams,
            /*PHTCollateralHelper.TokenParams memory tokenParams*/
            ,
            /*PHTCollateralHelper.FeedParams memory feedParams*/
        ) = PHTCollateralTestLib.addCollateralJoin(ilk, res, h, eve);
        vm.stopPrank();

        assertEq(IERC20Metadata(token).name(), "pDAI", "token name");
        assertEq(IERC20Metadata(token).symbol(), "pDAI", "token symbol");
        assertEq(uint256(IERC20Metadata(token).decimals()), 18, "token decimals");
        // ensure eve received the token balance
        assertEq(IERC20(token).balanceOf(eve), 1000 * 10 ** 18, "eve should have received the token balance");
        assertEq(IlkRegistry(res.ilkRegistry).count(), ilksCountBef + 1, "[PHTCollateralHelperTest] ilksCount");
        assertEq(address(pip), IlkRegistry(res.ilkRegistry).pip(ilk), "Same Pip");

        (bytes32 answer,) = pip.peek();
        assertApproxEqAbsDecimal(uint256(answer), 58e18, 0.2e18, 18, "1 DAI should be approx 58 PHT");

        Clipper ilkClip = Clipper(IlkRegistry(res.ilkRegistry).xlip(ilk));
        assertEq(ilkClip.buf(), ilkParams.buf);
        assertEq(ilkClip.tail(), ilkParams.tail);
        assertEq(ilkClip.cusp(), ilkParams.cusp);
        assertEq(uint256(ilkClip.chip()), uint256(ilkParams.chip));
        assertEq(uint256(ilkClip.tip()), uint256(ilkParams.tip));
        assertEq(ilkClip.chost(), ilkParams.dust * ilkParams.chop);

        // ensure pause.proxy auth
        DSPauseProxy proxy = DSPause(res.pause).proxy();

        vm.startPrank(eve);
        ProxyActions(res.proxyActions).rely(phpJoin, alice);
        assertEq(GemJoin(phpJoin).wards(address(proxy)), 1);
        assertEq(GemJoin(phpJoin).wards(alice), 1);
        assertEq(LinearDecrease(address(ilkClip.calc())).wards(address(proxy)), 1);
        vm.stopPrank();

        PriceJoinFeedAggregator feedObj = PriceJoinFeedAggregator(address(feed));
        assertEq(feedObj.description(), "DAI/PHT");
        assertEq(uint256(feedObj.decimals()), 8);
        assertEq(feedObj.version(), 1);
        assertEq(feedObj.live(), 1);

        // non-authority should not be able to admin feeds
        vm.expectRevert("ds-auth-unauthorized");
        feedObj.file("decimals", 12);

        // ensure that authority can update the feeds
        // created through the factory
        vm.startPrank(eve);
        feedObj.file("live", uint256(0));
        vm.expectRevert("PriceJoinFeedAggregator/not-live");
        feedObj.latestRoundData();
        vm.stopPrank();

        // test numerator feed
        PriceFeedAggregator numeratorFeed = PriceFeedAggregator(address(feedObj.numeratorFeed()));
        assertEq(numeratorFeed.description(), "DAI/USD");
        assertEq(uint256(numeratorFeed.decimals()), uint256(8));
        assertEq(numeratorFeed.live(), 1);
        // can call latestRoundData
        (, int256 numeratorAnswer,,,) = numeratorFeed.latestRoundData();
        assertEq(uint256(numeratorAnswer), 1e8, "numeratorAnswer");

        // non-authority should not be able to admin feeds
        vm.expectRevert("ds-auth-unauthorized");
        numeratorFeed.file("description", "something");

        // ensure that authority can update the feeds
        // created through the factory
        vm.startPrank(eve);
        numeratorFeed.file("description", "something");
        assertEq(numeratorFeed.description(), "something");

        numeratorFeed.file("live", uint256(0));
        vm.expectRevert("PriceFeedAggregator/not-live");
        numeratorFeed.latestRoundData();
        vm.stopPrank();

        // test denominator feed
        PriceFeedAggregator denominatorFeed = PriceFeedAggregator(address(feedObj.denominatorFeed()));
        assertEq(denominatorFeed.description(), "PHP/USD");
        assertEq(uint256(denominatorFeed.decimals()), uint256(8));
        assertEq(denominatorFeed.live(), 1);

        // can call latestRoundData
        (, int256 denominatorAnswer,,,) = denominatorFeed.latestRoundData();
        assertEq(uint256(denominatorAnswer), 1720000, "denominatorAnswer");

        // non-authority should not be able to admin feeds
        vm.expectRevert("ds-auth-unauthorized");
        denominatorFeed.file("description", "something");

        vm.expectRevert("ds-auth-unauthorized");
        denominatorFeed.file("live", uint256(0));

        // ensure that authority can update the feeds
        // created through the factory
        vm.startPrank(eve);
        denominatorFeed.file("description", "something");
        assertEq(denominatorFeed.description(), "something");
        denominatorFeed.file("live", uint256(0));
        vm.expectRevert("PriceFeedAggregator/not-live");
        denominatorFeed.latestRoundData();
        vm.stopPrank();
    }

    function test_rootCanAddCollateral() public {
        vm.startPrank(eve);
        PHTCollateralTestLib.addCollateral(getNextIlkName(res.ilkRegistry), res, h, eve);
        vm.stopPrank();
    }

    function test_shouldFailWithAuth() public {
        bytes32 ilkName = getNextIlkName(res.ilkRegistry);
        vm.expectRevert("ds-auth-unauthorized");
        PHTCollateralTestLib.addCollateral(ilkName, res, h, eve);
    }

    function test_ownerCannotAddCollateral() public {
        vm.startPrank(alice);
        bytes32 ilkName = getNextIlkName(res.ilkRegistry);
        vm.expectRevert("ds-auth-unauthorized");
        PHTCollateralTestLib.addCollateral(ilkName, res, h, alice);
        vm.stopPrank();
    }

    function test_tokenHelper_integration() public {
        vm.startPrank(eve);
        (,, address token,,,,) = PHTCollateralTestLib.addCollateral(getNextIlkName(res.ilkRegistry), res, h, eve);

        PHTTokenHelper(res.tokenHelper).mint(token, alice, 100e18);
        assertEqDecimal(IERC20(token).balanceOf(alice), 100e18, 18);
    }
}

interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}
