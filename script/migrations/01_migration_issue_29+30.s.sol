pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "forge-std/console.sol";
import "forge-std/StdCheats.sol";
import "forge-std/Script.sol";
import "forge-std/Test.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {stdJson} from "forge-std/StdJson.sol";

import {DSRoles, DSAuthority} from "../../pht/lib/Roles.sol";
import {ProxyActions} from "../../pht/helpers/ProxyActions.sol";
import {PHTCollateralHelper} from "../../pht/PHTCollateralHelper.sol";
import {PHTDeployResult, PHTDeploy, FiatTokenFactory, DSPause} from "../PHTDeploy.sol";

import {
    PHTDeploymentConfigJsonHelper, IPHTDeployConfigJson
} from "../../test/helpers/PHTDeploymentConfigJsonHelper.sol";
import {PriceFeedFactory, PriceFeedAggregator} from "../../pht/factory/PriceFeedFactory.sol";
import {PriceJoinFeedFactory, PriceJoinFeedAggregator} from "../../pht/factory/PriceJoinFeedFactory.sol";

// New Code
import {PHTTokenHelper, TokenActions} from "../../pht/PHTTokenHelper.sol";

/**
 * Fixes Issues:
 * `#29`: https://github.com/PHT-Stablecoin/dss/issues/29
 * `#29`: https://github.com/PHT-Stablecoin/dss/issues/30
 */
contract MigrationIssue29And30 is Script, PHTDeploy, Test {
    using stdJson for string;

    struct CollateralOutput {
        bytes32 ilk;
        address join;
        address token;
        uint256 tokenDecimals;
    }

    function run(string memory jsonFileName) public {
        PHTDeploymentConfigJsonHelper helper = new PHTDeploymentConfigJsonHelper();
        IPHTDeployConfigJson.Root memory config = helper.readDeploymentConfig(jsonFileName);
        console.log("[PHTDeploymentScript] starting...");
        console.log("[PHTDeploymentScript] msg.sender \t", msg.sender);
        console.log("[PHTDeploymentScript] address(this) \t", address(this));
        console.log("[PHTDeploymentScript] chainId \t", chainId());
        console.log("[PHTDeploymentScript] block.timestamp ", block.timestamp);
        console.log("[PHTDeploymentScript] block.number \t", block.number);

        PHTDeployResult memory res = readArtifacts(jsonFileName);
        console.log("[PHTDeployResult] authority \t", res.authority);
        console.log("[PHTDeployResult] tokenHelper (old) \t", res.tokenHelper);

        console.log("[MigrationIssue29And30] running: fixIssue29");
        console.log("[MigrationIssue29And30] link: https://github.com/PHT-Stablecoin/dss/issues/29");
        {
            vm.startBroadcast();
            DSRoles(res.authority).setAuthority(DSAuthority(res.authority));
            DSRoles(res.authority).setRootUser(DSRoles(res.authority).owner(), true);
            vm.stopBroadcast();

            assertEq(address(DSRoles(res.authority).authority()), res.authority);
            assertTrue(address(DSRoles(res.authority).isUserRoot(DSRoles(res.authority).owner())));
        }

        console.log("[MigrationIssue29And30] running: fixIssue30");
        console.log("[MigrationIssue29And30] link: https://github.com/PHT-Stablecoin/dss/issues/30");
        {
            vm.startBroadcast();

            // Setup newTokenHelper with `burn()`
            PHTTokenHelper newTokenHelper =
                new PHTTokenHelper(DSPause(res.pause), new TokenActions(), FiatTokenFactory(res.tokenFactory));
            console.log("[MigrationIssue29And30] deployed: newTokenHelper", address(newTokenHelper));
            console.log(
                "[MigrationIssue29And30] deployed: newTokenHelper.tokenActions", address(newTokenHelper.tokenActions())
            );
            console.log("[MigrationIssue29And30] setUserRole");
            DSRoles(address(res.authority)).setUserRole(address(newTokenHelper), ROLE_CAN_PLOT, true);
            ProxyActions(res.proxyActions).rely(address(res.tokenFactory), address(newTokenHelper));

            // Set CollateralHelper.tokenHelper = newTokenHelper
            console.log("[MigrationIssue29And30] collateralHelper.setTokenHelper(newTokenHelper)");
            console.log(
                "[MigrationIssue29And30] collateralHelper.tokenHelper (old)",
                address(PHTCollateralHelper(res.collateralHelper).tokenHelper())
            );
            console.log("[MigrationIssue29And30] collateralHelper.tokenHelper (new)", address(newTokenHelper));
            PHTCollateralHelper(res.collateralHelper).setTokenHelper(newTokenHelper);
            DSRoles(address(res.authority)).setUserRole(address(res.collateralHelper), ROLE_GOV_CREATE_TOKEN, true);
            DSRoles(address(res.authority)).setRoleCapability(
                ROLE_GOV_CREATE_TOKEN, address(newTokenHelper), newTokenHelper.createToken.selector, true
            );

            vm.stopBroadcast();

            res.tokenHelper = address(newTokenHelper);

            writeArtifacts("01_migration_issue_29+39.json", res);

            // Test
            {
                assertEq(
                    address(PHTCollateralHelper(res.collateralHelper).tokenHelper()),
                    address(newTokenHelper),
                    "collateralHelper.tokenHelper == newTokenHelper"
                );

                CollateralOutput memory testCollateral = _test_collateralHelper_create(res, config);
                _test_tokenHelper_burn(res, testCollateral);
            }
        }
    }

    function _test_collateralHelper_create(PHTDeployResult memory res, IPHTDeployConfigJson.Root memory config)
        internal
        returns (CollateralOutput memory collateralOutput)
    {
        PHTCollateralHelper h = PHTCollateralHelper(res.collateralHelper);
        IPHTDeployConfigJson.Collateral memory collateral = config.collaterals[0];
        IPHTDeployConfigJson.FeedParams memory feedParams = collateral.feedParams;
        IPHTDeployConfigJson.IlkParams memory ilkParams = collateral.ilkParams;
        IPHTDeployConfigJson.TokenParams memory tokenParams = collateral.tokenParams;

        // Modify Ilk Id
        ilkParams.ilk = "TEST_ILK";
        collateralOutput = CollateralOutput({
            ilk: ilkParams.ilk,
            join: address(0),
            token: address(0),
            tokenDecimals: tokenParams.decimals
        });

        console.log("[MigrationIssue29And30] _test_collateralHelper_create \t");

        (collateralOutput.join,, collateralOutput.token,) = h.addCollateral(
            res.ilkRegistry,
            PHTCollateralHelper.IlkParams({
                buf: ilkParams.buf, // already in RAY units
                chop: ilkParams.chop, // already in WAD units since cannot set 1.13 as value (float values are not supported)
                dust: ilkParams.dust,
                duty: ilkParams.duty,
                hole: ilkParams.holeRad * RAD,
                ilk: ilkParams.ilk,
                line: ilkParams.lineRad * RAD,
                mat: ilkParams.matEther * 1e18, // Liquidation Ratio
                tau: ilkParams.tau,
                tail: ilkParams.tail,
                cusp: ilkParams.cusp,
                chip: ilkParams.chip,
                tip: ilkParams.tip
            }),
            PHTCollateralHelper.TokenParams({
                token: tokenParams.token,
                symbol: tokenParams.symbol,
                name: tokenParams.name,
                decimals: tokenParams.decimals,
                currency: tokenParams.currency,
                maxSupply: tokenParams.maxSupply,
                initialSupply: tokenParams.initialSupply,
                initialSupplyMintTo: tokenParams.initialSupplyMintTo,
                tokenAdmin: tokenParams.tokenAdmin
            }),
            PHTCollateralHelper.FeedParams({
                factory: PriceFeedFactory(res.priceFeedFactory),
                joinFactory: PriceJoinFeedFactory(res.joinFeedFactory),
                feed: feedParams.feed,
                decimals: feedParams.decimals,
                initialPrice: feedParams.initialPrice,
                numeratorFeed: feedParams.numeratorFeed,
                invertNumerator: feedParams.invertNumerator,
                denominatorFeed: feedParams.denominatorFeed,
                invertDenominator: feedParams.invertDenominator,
                feedDescription: feedParams.feedDescription
            })
        );
    }

    function _test_tokenHelper_burn(PHTDeployResult memory res, CollateralOutput memory testCollateral) internal {
        address owner = DSRoles(res.authority).owner();
        vm.startPrank(owner);

        PHTTokenHelper(res.tokenHelper).mint(testCollateral.token, owner, 100 ** testCollateral.tokenDecimals);
        assertEqDecimal(
            IERC20(testCollateral.token).balanceOf(owner),
            100 ** testCollateral.tokenDecimals,
            testCollateral.tokenDecimals
        );

        // Approve Stage
        IERC20(testCollateral.token).approve(address(DSPause(res.pause).proxy()), 100 ** testCollateral.tokenDecimals);

        PHTTokenHelper(res.tokenHelper).burn(testCollateral.token, owner, 55 ** testCollateral.tokenDecimals);
        assertEqDecimal(
            IERC20(testCollateral.token).balanceOf(owner),
            (100 - 55) ** testCollateral.tokenDecimals,
            testCollateral.tokenDecimals
        );
    }

    function writeArtifacts(string memory jsonFileName, PHTDeployResult memory r) public {
        string memory root = vm.projectRoot();
        string memory path = string(
            abi.encodePacked(root, "/script/output/", vm.toString(chainId()), "/dssDeploy.artifacts.", jsonFileName)
        );

        console.log("[PHTDeploymentScript] writing artifacts to", path);

        string memory artifacts = "artifacts";
        // --- Auth ---
        artifacts.serialize("authority", r.authority);
        artifacts.serialize("mkrAuthority", r.mkrAuthority);
        artifacts.serialize("dssProxyActions", r.dssProxyActions);
        artifacts.serialize("dssProxyActionsEnd", r.dssProxyActionsEnd);
        artifacts.serialize("dssProxyActionsDsr", r.dssProxyActionsDsr);
        artifacts.serialize("dssProxyRegistry", r.dssProxyRegistry);
        artifacts.serialize("proxyActions", r.proxyActions);
        artifacts.serialize("dssCdpManager", r.dssCdpManager);
        artifacts.serialize("dsrManager", r.dsrManager);
        artifacts.serialize("gov", r.gov);
        artifacts.serialize("ilkRegistry", r.ilkRegistry);
        artifacts.serialize("pause", r.pause);
        // --- MCD ---
        artifacts.serialize("vat", r.vat);
        artifacts.serialize("jug", r.jug);
        artifacts.serialize("vow", r.vow);
        artifacts.serialize("cat", r.cat);
        artifacts.serialize("dog", r.dog);
        artifacts.serialize("flap", r.flap);
        artifacts.serialize("flop", r.flop);
        artifacts.serialize("dai", r.dai);
        artifacts.serialize("daiJoin", r.daiJoin);
        artifacts.serialize("spotter", r.spotter);
        artifacts.serialize("pot", r.pot);
        artifacts.serialize("cure", r.cure);
        artifacts.serialize("end", r.end);
        artifacts.serialize("esm", r.esm);
        artifacts.serialize("clog", r.clog);

        // --- Factories ---
        artifacts.serialize("priceFeedFactory", r.priceFeedFactory);
        artifacts.serialize("priceJoinFeedFactory", r.joinFeedFactory);
        artifacts.serialize("tokenFactory", r.tokenFactory);
        // --- Chainlink ---
        artifacts.serialize("feedPhpUsd", r.feedPhpUsd);

        // --- Helpers ----
        artifacts.serialize("collateralHelper", r.collateralHelper);
        artifacts.serialize("tokenHelper", r.tokenHelper);

        // --- ChainLog ---
        string memory json = artifacts.serialize("clog", r.clog);

        json.write(path);
    }

    function readArtifacts(string memory jsonFileName) internal returns (PHTDeployResult memory r) {
        string memory root = vm.projectRoot();
        string memory path = string(
            abi.encodePacked(root, "/script/output/", vm.toString(chainId()), "/dssDeploy.artifacts.", jsonFileName)
        );
        console.log("[PHTDeploymentScript] reading artifacts from", path);

        string memory artifacts = vm.readFile(path);

        r.authority = vm.parseJsonAddress(artifacts, ".authority");
        r.mkrAuthority = vm.parseJsonAddress(artifacts, ".mkrAuthority");
        r.dssProxyActions = vm.parseJsonAddress(artifacts, ".dssProxyActions");
        r.dssProxyActionsEnd = vm.parseJsonAddress(artifacts, ".dssProxyActionsEnd");
        r.dssProxyActionsDsr = vm.parseJsonAddress(artifacts, ".dssProxyActionsDsr");
        r.dssProxyRegistry = vm.parseJsonAddress(artifacts, ".dssProxyRegistry");
        r.proxyActions = vm.parseJsonAddress(artifacts, ".proxyActions");
        r.dssCdpManager = vm.parseJsonAddress(artifacts, ".dssCdpManager");
        r.dsrManager = vm.parseJsonAddress(artifacts, ".dsrManager");
        r.gov = vm.parseJsonAddress(artifacts, ".gov");
        r.ilkRegistry = vm.parseJsonAddress(artifacts, ".ilkRegistry");
        r.pause = vm.parseJsonAddress(artifacts, ".pause");

        // --- MCD ---
        r.vat = vm.parseJsonAddress(artifacts, ".vat");
        r.jug = vm.parseJsonAddress(artifacts, ".jug");
        r.vow = vm.parseJsonAddress(artifacts, ".vow");
        r.cat = vm.parseJsonAddress(artifacts, ".cat");
        r.dog = vm.parseJsonAddress(artifacts, ".dog");
        r.flap = vm.parseJsonAddress(artifacts, ".flap");
        r.flop = vm.parseJsonAddress(artifacts, ".flop");
        r.dai = vm.parseJsonAddress(artifacts, ".dai");
        r.daiJoin = vm.parseJsonAddress(artifacts, ".daiJoin");
        r.spotter = vm.parseJsonAddress(artifacts, ".spotter");
        r.pot = vm.parseJsonAddress(artifacts, ".pot");
        r.cure = vm.parseJsonAddress(artifacts, ".cure");
        r.end = vm.parseJsonAddress(artifacts, ".end");
        r.esm = vm.parseJsonAddress(artifacts, ".esm");
        r.clog = vm.parseJsonAddress(artifacts, ".clog");

        // --- Factories ---
        r.priceFeedFactory = vm.parseJsonAddress(artifacts, ".priceFeedFactory");
        r.joinFeedFactory = vm.parseJsonAddress(artifacts, ".priceJoinFeedFactory");
        r.tokenFactory = vm.parseJsonAddress(artifacts, ".tokenFactory");
        // --- Chainlink ---
        r.feedPhpUsd = vm.parseJsonAddress(artifacts, ".feedPhpUsd");

        // --- Helpers ----
        r.collateralHelper = vm.parseJsonAddress(artifacts, ".collateralHelper");
        r.tokenHelper = vm.parseJsonAddress(artifacts, ".tokenHelper");
    }
}
