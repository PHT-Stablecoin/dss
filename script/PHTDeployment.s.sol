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

contract PHTDeploymentScript is Script, PHTDeploy, Test {
    using ArrayHelpers for *;
    using stdJson for string;

    bytes32 constant ILK_NAME = bytes32("PHP-A");

    function run() public {
        vm.startBroadcast();

        console.log("[PHTDeploymentScript] starting...");
        console.log("[PHTDeploymentScript] msg.sender \t", msg.sender);
        console.log("[PHTDeploymentScript] address(this) \t", address(this));
        console.log("[PHTDeploymentScript] chainId \t", chainId());
        console.log("[PHTDeploymentScript] block.timestamp ", block.timestamp);
        console.log("[PHTDeploymentScript] block.number \t", block.number);

        // @TODO move this to a per-chain json
        PHTDeployResult memory res = deploy(
            PHTDeployConfig({
                govTokenSymbol: "APC",
                phtUsdFeed: address(0), // only for sepolia / local testing
                dogHoleRad: 10_000_000,
                vatLineRad: 10_000_000,
                jugBase: 0.0000000006279e27, // 0.00000006279% => 2% base global fee
                authorityOwner: msg.sender,
                // this is needed in order to be able to call addCollateral() in PHTDeploymentHelper
                authorityRootUsers: [msg.sender].toMemoryArray()
            })
        );

        PHTCollateralHelper h = PHTCollateralHelper(res.collateralHelper);

        // @TODO move this to a per-chain json as global config above
        (address join, , address token, ) = h.addCollateral(
            address(dssDeploy.pause().proxy()),
            res.ilkRegistry,
            PHTCollateralHelper.IlkParams({
                ilk: ILK_NAME,
                line: uint(5_000_000 * RAD), // Set PHP-A limit to 5 million DAI (RAD units)
                dust: uint(0),
                tau: 1 hours,
                mat: uint(1050000000 ether), // Liquidation Ratio (105%),
                hole: 5_000_000 * RAD, // Set PHP-A limit to 5 million DAI (RAD units)
                chop: 1.13e18, // Set the liquidation penalty (chop) for "PHP-A" to 13% (1.13e18 in WAD units)
                buf: 1.20e27, // Set a 20% increase in auctions (RAY)
                // duty: 1.0000000018477e27 // 0.00000018477% => 6% Annual duty
                duty: 1.0000000012436807e27 // => 4%
            }),
            PHTCollateralHelper.TokenParams({
                factory: ITokenFactory(res.tokenFactory),
                token: address(0),
                symbol: "tstPHP",
                name: "Testtttttttt PHP",
                decimals: 6,
                maxSupply: 0,
                initialSupply: 1000 * 10 ** 6
            }),
            PHTCollateralHelper.FeedParams({
                factory: PriceFeedFactory(res.priceFeedFactory),
                joinFactory: PriceJoinFeedFactory(res.joinFeedFactory),
                feed: address(0),
                decimals: 6,
                initialPrice: int(1 * 10 ** 6), // Price 1 DAI (PHT) = 1 PHP (precision 6)
                numeratorFeed: address(0),
                invertNumerator: false,
                denominatorFeed: address(0),
                invertDenominator: false,
                feedDescription: ""
            })
        );
        vm.stopBroadcast();

        assertEq(IERC20(token).balanceOf(msg.sender), 1000 * 10 ** 6, "msg.sender should have 1000 tstPHP");
        assertTrue(DSRoles(res.authority).isUserRoot(msg.sender), "msg.sender is root");

        _test_openLockGemAndDraw(res, msg.sender, ILK_NAME, token, join);

        writeArtifacts(res);
    }

    function _test_openLockGemAndDraw(
        PHTDeployResult memory res,
        address bob,
        bytes32 ilk,
        address token,
        address join
    ) private {
        vm.prank(msg.sender);
        IERC20(token).transfer(bob, 1000 * 10 ** 6);

        // Move Blocktime to 10 blocks ahead
        vm.warp(now + 100);

        // normal user opens a CDP
        vm.startPrank(bob);
        PHTOpsTestLib.openLockGemAndDraw(res, bob, ilk, token, join);
        vm.stopPrank();
    }

    function writeArtifacts(PHTDeployResult memory r) public {
        string memory root = vm.projectRoot();
        string memory path = string(
            abi.encodePacked(root, "/script/output/", vm.toString(chainId()), "/dssDeploy.artifacts.json")
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
