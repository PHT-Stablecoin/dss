pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "forge-std/Script.sol";
import "forge-std/Test.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {IlkRegistry} from "dss-ilk-registry/IlkRegistry.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {PHTDeploy, PHTDeployResult} from "../script/PHTDeploy.sol";
import {PHTCollateralHelper} from "../pht/PHTCollateralHelper.sol";
import {PHTDeployConfig} from "./PHTDeployConfig.sol";
import {DSRoles} from "../pht/lib/Roles.sol";
import {ArrayHelpers} from "../pht/lib/ArrayHelpers.sol";
import {PriceFeedFactory} from "../pht/factory/PriceFeedFactory.sol";
import {PriceJoinFeedFactory} from "../pht/factory/PriceJoinFeedFactory.sol";
import {PHTOpsTestLib} from "../test/helpers/PHTOpsTestLib.sol";
import {ITokenFactory} from "../fiattoken/FiatTokenFactory.sol";
import {PHTDeploymentConfigJsonHelper, IPHTDeployConfigJson} from "../test/helpers/PHTDeploymentConfigJsonHelper.sol";

contract PHTDeploymentScript is Script, PHTDeploy, Test {
    using ArrayHelpers for *;
    using stdJson for string;

    struct CollateralOutput {
        bytes32 ilk;
        address join;
        address token;
        uint256 tokenDecimals;
    }

    function run(string memory jsonFileName) public {
        IPHTDeployConfigJson.Root memory config;
        {
            PHTDeploymentConfigJsonHelper helper = new PHTDeploymentConfigJsonHelper();
            config = helper.readDeploymentConfig(jsonFileName);
            console.log("[PHTDeploymentScript] starting...");
            console.log("[PHTDeploymentScript] msg.sender \t", msg.sender);
            console.log("[PHTDeploymentScript] address(this) \t", address(this));
            console.log("[PHTDeploymentScript] chainId \t", chainId());
            console.log("[PHTDeploymentScript] block.timestamp ", block.timestamp);
            console.log("[PHTDeploymentScript] block.number \t", block.number);
        }

        _sanitizeConfig(config);

        vm.startBroadcast();

        PHTDeployResult memory res = deploy(
            PHTDeployConfig({
                govTokenSymbol: config.govTokenSymbol,
                phtUsdFeed: config.phtUsdFeed, // only for sepolia / local testing
                dogHoleRad: config.dogHoleRad,
                vatLineRad: config.vatLineRad,
                // jugBase: 0.0000000006279e27, // 0.00000006279% => 2% base global fee
                jugBase: config.jugBase, // 0.00000006279% => 2% base global fee
                authorityOwner: config.authorityOwner,
                // this is needed in order to be able to call addCollateral() in PHTDeploymentHelper
                authorityRootUsers: config.authorityRootUsers
            })
        );

        PHTCollateralHelper h = PHTCollateralHelper(res.collateralHelper);
        CollateralOutput[] memory collateralOutputs = new CollateralOutput[](config.collaterals.length);
        for (uint256 i = 0; i < config.collaterals.length; i++) {
            console.log("[PHTDeploymentScript] adding collateral \t", i);
            IPHTDeployConfigJson.Collateral memory collateral = config.collaterals[i];
            IPHTDeployConfigJson.FeedParams memory feedParams = collateral.feedParams;
            IPHTDeployConfigJson.IlkParams memory ilkParams = collateral.ilkParams;
            IPHTDeployConfigJson.TokenParams memory tokenParams = collateral.tokenParams;

            collateralOutputs[i] = CollateralOutput({
                ilk: ilkParams.ilk,
                join: address(0),
                token: address(0),
                tokenDecimals: tokenParams.decimals
            });

            (collateralOutputs[i].join,, collateralOutputs[i].token,) = h.addCollateral(
                address(dssDeploy.pause().proxy()),
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
                    cusp: ilkParams.cusp,
                    chip: ilkParams.chip,
                    tip: ilkParams.tip,
                    tail: ilkParams.tail
                }),
                PHTCollateralHelper.TokenParams({
                    factory: ITokenFactory(res.tokenFactory),
                    token: tokenParams.token,
                    symbol: tokenParams.symbol,
                    name: tokenParams.name,
                    decimals: tokenParams.decimals,
                    maxSupply: tokenParams.maxSupply,
                    initialSupply: tokenParams.initialSupply
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
        // only write artifacts if we're in broadcast mode
        writeArtifacts(jsonFileName, res);

        vm.stopBroadcast();

        assertTrue(DSRoles(res.authority).isUserRoot(msg.sender), "msg.sender is root");

        _test_openLockGemAndDraw(res, collateralOutputs);
    }

    function _sanitizeConfig(IPHTDeployConfigJson.Root memory config) private {
        console.log("[PHTDeploymentScript] _sanitizeConfig starting...");
        if (config.phtUsdFeed != address(0)) {
            AggregatorV3Interface feed = AggregatorV3Interface(config.phtUsdFeed);
            assertTrue(feed.decimals() >= 0, "phtUsdFeed decimals");
            (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
                feed.latestRoundData();
            assertTrue(startedAt > 0, "phtUsdFeed startedAt");
            assertTrue(updatedAt > 0, "phtUsdFeed updatedAt");
            assertTrue(answeredInRound > 0, "phtUsdFeed answeredInRound");
            assertTrue(answer > 0, "phtUsdFeed answer");
        }
        console.log("[PHTDeploymentScript] _sanitizeConfig done");
    }

    function _test_openLockGemAndDraw(PHTDeployResult memory res, CollateralOutput[] memory collateralOutputs)
        private
    {
        address bob = makeAddr("bob");
        for (uint256 i = 0; i < collateralOutputs.length; i++) {
            CollateralOutput memory collateral = collateralOutputs[i];
            deal(collateral.token, bob, 1000 * 10 ** collateral.tokenDecimals);
            // Move Blocktime
            vm.warp(now + 1);
            vm.startPrank(bob);
            PHTOpsTestLib.openLockGemAndDraw(res, bob, collateral.ilk, collateral.token, collateral.join);
            vm.stopPrank();
        }
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
        // --- ChainLog ---
        artifacts.serialize("clog", r.clog);

        // --- Factories ---
        artifacts.serialize("priceFeedFactory", r.priceFeedFactory);
        artifacts.serialize("priceJoinFeedFactory", r.joinFeedFactory);
        artifacts.serialize("tokenFactory", r.tokenFactory);
        // --- Chainlink ---
        artifacts.serialize("feedPhpUsd", r.feedPhpUsd);

        // --- Helpers ----
        string memory json = artifacts.serialize("collateralHelper", r.collateralHelper);

        json.write(path);
    }
}

interface AggregatorV3Interface {
    function decimals() external view returns (uint8);

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}
