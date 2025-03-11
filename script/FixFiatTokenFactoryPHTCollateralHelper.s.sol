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
import {ProxyInitializer} from "../fiattoken/ProxyInitializer.sol";
import {MasterMinterDeployer} from "../fiattoken/MasterMinterDeployer.sol";

contract FixFiatTokenFactoryPHTCollateralHelper is Script, PHTDeploy, Test {
    using ArrayHelpers for *;

    function run() public {
        vm.startBroadcast();

        ProxyInitializer proxyInitializer = new ProxyInitializer();
        console.log("proxyInitializer", address(proxyInitializer));

        // MasterMinterDeployer masterMinterDeployer = new MasterMinterDeployer();
        // console.log("masterMinterDeployer", address(masterMinterDeployer));

        // tokenFactory = deployFiatTokenFactory();
        // console.log("tokenFactory", address(tokenFactory));
        // tokenFactory.rely(address(dssDeploy.pause().proxy()));
        // tokenFactory.deny(address(this));

        // @TODO permissions

        // PHTCollateralHelper

        vm.stopBroadcast();

        // assertTrue(DSRoles(res.authority).isUserRoot(msg.sender), "msg.sender is root");

        // _test_openLockGemAndDraw(res, collateralOutputs);
    }

    // function _test_openLockGemAndDraw(PHTDeployResult memory res, CollateralOutput[] memory collateralOutputs)
    //     private
    // {
    //     address bob = makeAddr("bob");
    //     for (uint256 i = 0; i < collateralOutputs.length; i++) {
    //         CollateralOutput memory collateral = collateralOutputs[i];
    //         deal(collateral.token, bob, 1000 * 10 ** collateral.tokenDecimals);
    //         // Move Blocktime
    //         vm.warp(now + 1);
    //         vm.startPrank(bob);
    //         PHTOpsTestLib.openLockGemAndDraw(res, bob, collateral.ilk, collateral.token, collateral.join);
    //         vm.stopPrank();
    //     }
    // }

    // @TODO manually update the relevant addresses in the json file
    // function writeArtifacts(string memory jsonFileName, PHTDeployResult memory r) public {

    //     // --- Factories ---
    //     artifacts.serialize("tokenFactory", r.tokenFactory);

    //     // --- Helpers ----
    //     artifacts.serialize("collateralHelper", r.collateralHelper);
    //     artifacts.serialize("tokenHelper", r.tokenHelper);

    //     // --- ChainLog ---
    //     string memory json = artifacts.serialize("clog", r.clog);

    //     json.write(path);
    // }
}
