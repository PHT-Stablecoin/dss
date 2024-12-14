pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import {console} from "forge-std/console.sol";

import {PHTCollateralHelper} from "../../pht/PHTCollateralHelper.sol";
import {PHTDeploy, PHTDeployResult} from "../../pht/PHTDeploy.sol";
import {ChainlinkPip, AggregatorV3Interface} from "../../pht/helpers/ChainlinkPip.sol";
import {PriceFeedFactory, PriceFeedAggregator} from "../../pht/factory/PriceFeedFactory.sol";
import {PriceJoinFeedFactory, PriceJoinFeedAggregator} from "../../pht/factory/PriceJoinFeedFactory.sol";
import {IlkRegistry} from "dss-ilk-registry/IlkRegistry.sol";

library PHTCollateralTestLib {
    uint256 constant RAD = 10 ** 45;
    function addCollateral(
        bytes32 ilkName,
        PHTDeployResult memory res,
        PHTCollateralHelper h,
        address owner
    ) internal returns (address join, AggregatorV3Interface feed, address token, ChainlinkPip pip) {
        return
            h.addCollateral(
                owner,
                IlkRegistry(res.ilkRegistry),
                PHTCollateralHelper.IlkParams({
                    ilk: ilkName,
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
                    token: address(0),
                    symbol: "tstPHP",
                    name: "Test PHP",
                    decimals: 6,
                    maxSupply: 0,
                    initialSupply: 1000 * 10 ** 6
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
