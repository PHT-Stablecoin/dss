pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import {console} from "forge-std/console.sol";

import {PHTCollateralHelper} from "../../pht/PHTCollateralHelper.sol";
import {PHTDeploy, PHTDeployResult} from "../../script/PHTDeploy.sol";
import {ChainlinkPip, AggregatorV3Interface} from "../../pht/helpers/ChainlinkPip.sol";
import {PriceFeedFactory, PriceFeedAggregator} from "../../pht/factory/PriceFeedFactory.sol";
import {PriceJoinFeedFactory, PriceJoinFeedAggregator} from "../../pht/factory/PriceJoinFeedFactory.sol";
import {IlkRegistry} from "dss-ilk-registry/IlkRegistry.sol";
import {ITokenFactory} from "../../fiattoken/FiatTokenFactory.sol";

library PHTCollateralTestLib {
    uint256 constant RAD = 10 ** 45;

    function addCollateral(bytes32 ilkName, PHTDeployResult memory res, PHTCollateralHelper h, address mintTo)
        internal
        returns (
            address join,
            AggregatorV3Interface feed,
            address token,
            ChainlinkPip pip,
            PHTCollateralHelper.IlkParams memory ilkParams,
            PHTCollateralHelper.TokenParams memory tokenParams,
            PHTCollateralHelper.FeedParams memory feedParams
        )
    {
        ilkParams = PHTCollateralHelper.IlkParams({
            ilk: ilkName,
            line: uint256(5_000_000 * RAD), // Set PHP-A limit to 5 million DAI (RAD units)
            dust: uint256(0),
            tau: 1 hours,
            mat: uint256(1050000000 ether), // Liquidation Ratio (105%),
            hole: 5_000_000 * RAD, // Set PHP-A limit to 5 million DAI (RAD units)
            chop: 1.13e18, // Set the liquidation penalty (chop) for "PHP-A" to 13% (1.13e18 in WAD units)
            buf: 1.2e27, // Set a 20% increase in auctions (RAY)
            // duty: 1.0000000018477e27 // 0.00000018477% => 6% Annual duty
            duty: 1.0000000012436807e27, // => 4%
            tail: 100, // 200s before auction reset
            cusp: uint256(0.02e45), // 2% percentage drop (Rad units)
            chip: uint64(0.01e18), // 1% of tab from vow to incentivize keepers
            tip: uint192(0) // 0 fee on flat fee since we have 0 for dust
        });

        tokenParams = PHTCollateralHelper.TokenParams({
            token: address(0),
            name: "Test PHP",
            symbol: "tstPHP",
            decimals: 6,
            currency: "PHP",
            maxSupply: 0,
            initialSupply: 1000 * 10 ** 6,
            initialSupplyMintTo: mintTo,
            tokenAdmin: address(1)
        });

        feedParams = PHTCollateralHelper.FeedParams({
            factory: PriceFeedFactory(res.priceFeedFactory),
            joinFactory: PriceJoinFeedFactory(res.joinFeedFactory),
            feed: address(0),
            decimals: 6,
            initialPrice: int256(1 * 10 ** 6), // Price 1 DAI (PHT) = 1 PHP (precision 6)
            numeratorFeed: address(0),
            invertNumerator: false,
            denominatorFeed: address(0),
            invertDenominator: false,
            feedDescription: ""
        });

        (join, feed, token, pip) = h.addCollateral(res.ilkRegistry, ilkParams, tokenParams, feedParams);
    }

    function addCollateralJoin(bytes32 ilkName, PHTDeployResult memory res, PHTCollateralHelper h, address mintTo)
        internal
        returns (
            address join,
            AggregatorV3Interface feed,
            address token,
            ChainlinkPip pip,
            PHTCollateralHelper.IlkParams memory ilkParams,
            PHTCollateralHelper.TokenParams memory tokenParams,
            PHTCollateralHelper.FeedParams memory feedParams
        )
    {
        ilkParams = PHTCollateralHelper.IlkParams({
            ilk: ilkName,
            line: uint256(10000 * 10 ** 45),
            dust: uint256(0),
            tau: 1 hours,
            mat: uint256(1500000000 ether), // mat: Liquidation Ratio (150%),
            hole: 5_000_000 * RAD, // Set USDT-A limit to 5 million DAI (RAD units)
            chop: 1.13e18, // Set the liquidation penalty (chop) for "USDT-A" to 13% (1.13e18 in WAD units)
            buf: 1.2e27, // Set a 20% increase in auctions (RAY)
            duty: 1.0000000018477e27, // 0.00000018477% => 6% Annual duty
            tail: 100, // 200s before auction reset
            cusp: uint256(0.02e45), // 2% percentage drop (Rad units)
            chip: uint64(0.01e18), // 1% of tab from vow to incentivize keepers
            tip: uint192(0) // 0 fee on flat fee since we have 0 for dust
        });

        tokenParams = PHTCollateralHelper.TokenParams({
            token: address(0),
            symbol: "pDAI",
            name: "pDAI",
            currency: "PHP",
            decimals: 18,
            maxSupply: 0,
            initialSupply: 1000e18,
            initialSupplyMintTo: mintTo,
            tokenAdmin: address(1)
        });

        feedParams = PHTCollateralHelper.FeedParams({
            factory: PriceFeedFactory(res.priceFeedFactory),
            joinFactory: PriceJoinFeedFactory(res.joinFeedFactory),
            feed: address(0),
            decimals: 0,
            initialPrice: int256(0),
            numeratorFeed: address(PriceFeedFactory(res.priceFeedFactory).create(8, int256(1e8), "DAI/USD")),
            invertNumerator: false,
            denominatorFeed: address(PriceFeedFactory(res.priceFeedFactory).create(8, int256(0.0172e8), "PHP/USD")),
            invertDenominator: true,
            feedDescription: "DAI/PHT"
        });

        (join, feed, token, pip) = h.addCollateral(res.ilkRegistry, ilkParams, tokenParams, feedParams);
    }
}
