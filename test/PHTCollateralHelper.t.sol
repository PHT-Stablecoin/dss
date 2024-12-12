pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {DssDeploy, Clipper} from "lib/dss-cdp-manager/lib/dss-deploy/src/DssDeploy.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {DSRoles} from "../pht/lib/Roles.sol";
import {PHTDeploy, PHTDeployResult} from "../pht/PHTDeploy.sol";
import {PHTCollateralHelper} from "../pht/PHTCollateralHelper.sol";
import {PriceFeedFactory, PriceFeedAggregator} from "../pht/factory/PriceFeedFactory.sol";
import {PriceJoinFeedFactory, PriceJoinFeedAggregator} from "../pht/factory/PriceJoinFeedFactory.sol";
import {ChainlinkPip, AggregatorV3Interface} from "../pht/helpers/ChainlinkPip.sol";
import {IlkRegistry} from "dss-ilk-registry/IlkRegistry.sol";

import {PHTDeployConfig, PHTDeployCollateralConfig} from "../pht/PHTDeployConfig.sol";
import {ArrayHelpers} from "../pht/lib/ArrayHelpers.sol";

contract PHTCollateralHelperTest is Test {
    using ArrayHelpers for *;

    // --- Math ---
    uint256 constant WAD = 10 ** 18;
    uint256 constant RAY = 10 ** 27;
    uint256 constant RAD = 10 ** 45;

    // -- ROLES --
    uint8 constant ROLE_GOV_MINT_BURN = 10;
    uint8 constant ROLE_CAN_PLOT = 11;

    function test_addCollateral() public {
        address eve = makeAddr("eve");
        PHTDeployCollateralConfig[] memory collateralConfigs = new PHTDeployCollateralConfig[](0);
        PHTDeploy d = new PHTDeploy();
        PHTDeployResult memory res = d.deploy(
            PHTDeployConfig({
                govTokenSymbol: "APC",
                dogHoleRad: 10_000_000,
                vatLineRad: 10_000_000,
                jugBase: 0.0000000006279e27, // 0.00000006279% => 2% base global fee
                rootUsers: [eve].toMemoryArray(),
                collateralConfigs: collateralConfigs
            })
        );
        PHTCollateralHelper h = PHTCollateralHelper(res.collateralHelper);

        vm.prank(eve);
        
        // // address phpAddr;
        (address phpJoin, AggregatorV3Interface feedPHP, address phpAddr, ChainlinkPip pipPHP) = h.addCollateral(
            address(this),
            IlkRegistry(res.ilkRegistry),
            PHTCollateralHelper.IlkParams({
                ilk: "PHP-A",
                line: uint(5_000_000 * 10 ** 45), // Set PHP-A limit to 5 million DAI (RAD units)
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
                token: address(0),
                symbol: "tstPHP",
                name: "Test PHP",
                decimals: 6,
                maxSupply: 0
            }),
            PHTCollateralHelper.FeedParams({
                factory: PriceFeedFactory(res.feedFactory),
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
    }
}
