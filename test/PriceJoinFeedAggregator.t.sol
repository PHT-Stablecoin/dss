pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PHTDeploy, PHTDeployResult} from "../script/PHTDeploy.sol";
import {PHTTokenHelper} from "../pht/PHTTokenHelper.sol";
import {PHTDeployConfig} from "../script/PHTDeployConfig.sol";
import {ArrayHelpers} from "../pht/lib/ArrayHelpers.sol";
import {PriceJoinFeedAggregator} from "../pht/factory/PriceJoinFeedAggregator.sol";

import {MockAggregatorV3} from "./helpers/MockAggregatorV3.sol";

struct Data {
    string description;
    int256 numeratorAnswer;
    uint256 numeratorDecimals;
    int256 denominatorAnswer;
    uint256 denominatorDecimals;
    uint256 feedDecimals;
    bool invertNumerator;
    bool invertDenominator;
    int256 expectedAnswer;
}

contract PriceJoinFeedAggregatorTest is Test {
    function test_PriceJoinFeedAggregator() public {
        Data[] memory data = new Data[](20);

        // all feeds below are expressing a token in PHP ultimately
        // this is the reason why we invert the denominator in order
        // to flip PHP / USD to USD / PHP
        data[0] = Data({
            description: "USDC / USD * PHP / USD (inverted denominator): 8 decimals",
            // price of USDC in USD (1e8 precision)
            numeratorAnswer: int256(1e8),
            numeratorDecimals: 8,
            // this is the price of PHP in USD (1e8 precision)
            // therefore we need to invert it to get USD -> PHP
            // so that we have USDC -> PHP
            denominatorAnswer: int256(0.01711902 * 1e8),
            denominatorDecimals: 8,
            feedDecimals: 8,
            invertNumerator: false,
            invertDenominator: true,
            // 1e8 / 1711902 = 58.4145587773
            // 1 USDC = 1 USD = 5841455877 PHP (in 1e8 precision)
            expectedAnswer: 5841455877
        });
        data[1] = Data({
            description: "USDC / USD * PHP / USD (inverted denominator): 12 decimals",
            numeratorAnswer: int256(1e12),
            numeratorDecimals: 12,
            denominatorAnswer: int256(0.01711902 * 1e12),
            denominatorDecimals: 12,
            feedDecimals: 8,
            invertNumerator: false,
            invertDenominator: true,
            // we still expect an answer in 1e8 precision
            expectedAnswer: 5841455877
        });

        data[2] = Data({
            description: "USDC / USD * PHP / USD (inverted denominator): 18 decimals",
            numeratorAnswer: int256(1e18),
            numeratorDecimals: 18,
            denominatorAnswer: int256(0.01711902 * 1e18),
            denominatorDecimals: 18,
            feedDecimals: 8,
            invertNumerator: false,
            invertDenominator: true,
            // we still expect an answer in 1e8 precision
            expectedAnswer: 5841455877
        });
        data[3] = Data({
            description: "USD / SGD * PHP / USD (inverted NUMERATOR && DENOMINATOR): 8 decimals",
            numeratorAnswer: int256(1.36063 * 1e8),
            numeratorDecimals: 8,
            denominatorAnswer: int256(0.01711902 * 1e8),
            denominatorDecimals: 8,
            feedDecimals: 8,
            invertNumerator: true,
            invertDenominator: true,
            expectedAnswer: 4293199383
        });
        data[4] = Data({
            description: "USD / SGD * PHP / USD (inverted NUMERATOR && DENOMINATOR): 18 decimals NUMERATOR, 8 decimals DENOMINATOR",
            numeratorAnswer: int256(1.36063 * 1e18),
            numeratorDecimals: 18,
            denominatorAnswer: int256(0.01711902 * 1e8),
            denominatorDecimals: 8,
            feedDecimals: 8,
            invertNumerator: true,
            invertDenominator: true,
            expectedAnswer: 4293199383
        });

        data[5] = Data({
            description: "SGD / USD * USD / PHP (no inversion): 8 decimals",
            numeratorAnswer: int256(0.7361171 * 1e8),
            numeratorDecimals: 8,
            denominatorAnswer: int256(58.520789 * 1e8),
            denominatorDecimals: 8,
            feedDecimals: 8,
            invertNumerator: false,
            invertDenominator: false,
            expectedAnswer: 4307815348
        });
        // test 0 decimals denominator
        data[6] = Data({
            description: "SGD / USD * USD / PHP (no inversion): 8 decimals && 0 decimals",
            numeratorAnswer: int256(0.7361171 * 1e8),
            numeratorDecimals: 8,
            denominatorAnswer: int256(58),
            denominatorDecimals: 0,
            feedDecimals: 8,
            invertNumerator: false,
            invertDenominator: false,
            expectedAnswer: 4269479180
        });
        // test different feed decimals
        data[7] = Data({
            description: "USDC / USD * PHP / USD (inverted denominator): 8 decimals & feed 18 decimals",
            // price of USDC in USD (1e8 precision)
            numeratorAnswer: int256(1e8),
            numeratorDecimals: 8,
            // this is the price of PHP in USD (1e8 precision)
            // therefore we need to invert it to get USD -> PHP
            // so that we have USDC -> PHP
            denominatorAnswer: int256(0.01711902 * 1e8),
            denominatorDecimals: 8,
            feedDecimals: 18,
            invertNumerator: false,
            invertDenominator: true,
            expectedAnswer: 58414558777313187320
        });

        for (uint256 i = 0; i < data.length; i++) {
            Data memory d = data[i];
            if (d.numeratorDecimals == 0) {
                continue;
            }

            MockAggregatorV3 numeratorFeed = new MockAggregatorV3();
            numeratorFeed.file("answer", d.numeratorAnswer);
            numeratorFeed.file("decimals", d.numeratorDecimals);

            MockAggregatorV3 denominatorFeed = new MockAggregatorV3();
            denominatorFeed.file("answer", d.denominatorAnswer);
            denominatorFeed.file("decimals", d.denominatorDecimals);

            PriceJoinFeedAggregator aggregator = new PriceJoinFeedAggregator(
                address(numeratorFeed), address(denominatorFeed), d.invertNumerator, d.invertDenominator, d.description
            );
            if (d.feedDecimals != aggregator.decimals()) {
                aggregator.file("decimals", d.feedDecimals);
            }
            (, int256 answer,,,) = aggregator.latestRoundData();
            assertEq(answer, d.expectedAnswer, d.description);

            // simulate changing the numerator feed by changing the decimals
            if (d.numeratorDecimals < 17) {
                numeratorFeed.file("answer", d.numeratorAnswer * 1e2);
                numeratorFeed.file("decimals", d.numeratorDecimals + 2);
            } else {
                numeratorFeed.file("answer", d.numeratorAnswer / 1e2);
                numeratorFeed.file("decimals", d.numeratorDecimals - 2);
            }
            aggregator.file("numeratorFeed", address(numeratorFeed), d.invertNumerator);
            (, answer,,,) = aggregator.latestRoundData();
            assertEq(answer, d.expectedAnswer, d.description);
        }
    }
}
