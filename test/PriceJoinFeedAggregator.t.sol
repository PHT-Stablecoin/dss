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
    bool invertNumerator;
    bool invertDenominator;
    int256 expectedAnswer;
    uint256 expectedFeedDecimals;
}

contract PriceJoinFeedAggregatorTest is Test {
    function test_PriceJoinFeedAggregator() public {
        Data[] memory data = new Data[](20);

        // all feeds below are expressing a token in PHP ultimately
        // this is the reason why we invert the denominator in order
        // to flip PHP / USD to USD / PHP
        data[0] = Data({
            description: "#0: USDC / USD * PHP / USD (inverted denominator): 8 decimals",
            // price of USDC in USD (1e8 precision)
            numeratorAnswer: int256(1e8),
            numeratorDecimals: 8,
            // this is the price of PHP in USD (1e8 precision)
            // therefore we need to invert it to get USD -> PHP
            // so that we have USDC -> PHP
            denominatorAnswer: int256(0.01711902 * 1e8),
            denominatorDecimals: 8,
            invertNumerator: false,
            invertDenominator: true,
            // 1e8 / 1711902 = 58.4145587773
            // 1 USDC = 1 USD = 5841455877 PHP (in 1e8 precision)
            expectedAnswer: 5841455877,
            expectedFeedDecimals: 8
        });
        data[1] = Data({
            description: "#1: USDC / USD * PHP / USD (inverted denominator): 12 decimals",
            numeratorAnswer: int256(1e12),
            numeratorDecimals: 12,
            denominatorAnswer: int256(0.01711902 * 1e12),
            denominatorDecimals: 12,
            invertNumerator: false,
            invertDenominator: true,
            expectedAnswer: 58.414558777313 * 1e12,
            expectedFeedDecimals: 12
        });

        data[2] = Data({
            description: "#2: USDC / USD * PHP / USD (inverted denominator): 18 decimals",
            numeratorAnswer: int256(1e18),
            numeratorDecimals: 18,
            denominatorAnswer: int256(0.01711902 * 1e18),
            denominatorDecimals: 18,
            invertNumerator: false,
            invertDenominator: true,
            expectedAnswer: 58.41455877731318732 * 1e18,
            expectedFeedDecimals: 18
        });
        data[3] = Data({
            description: "#3: USD / SGD * PHP / USD (inverted NUMERATOR && DENOMINATOR): 8 decimals",
            numeratorAnswer: int256(1.36063 * 1e8),
            numeratorDecimals: 8,
            denominatorAnswer: int256(0.01711902 * 1e8),
            denominatorDecimals: 8,
            invertNumerator: true,
            invertDenominator: true,
            expectedAnswer: 4293199383,
            expectedFeedDecimals: 8
        });
        data[4] = Data({
            description: "#4: USD / SGD * PHP / USD (inverted NUMERATOR && DENOMINATOR): 18 decimals NUMERATOR, 8 decimals DENOMINATOR",
            numeratorAnswer: int256(1.36063 * 1e18),
            numeratorDecimals: 18,
            denominatorAnswer: int256(0.01711902 * 1e8),
            denominatorDecimals: 8,
            invertNumerator: true,
            invertDenominator: true,
            expectedAnswer: 42.931993839113636528 * 1e18,
            expectedFeedDecimals: 18
        });

        data[5] = Data({
            description: "#5: SGD / USD * USD / PHP (no inversion): 8 decimals",
            numeratorAnswer: int256(0.7361171 * 1e8),
            numeratorDecimals: 8,
            denominatorAnswer: int256(58.520789 * 1e8),
            denominatorDecimals: 8,
            invertNumerator: false,
            invertDenominator: false,
            expectedAnswer: 43.07815348 * 1e8,
            expectedFeedDecimals: 8
        });
        // test 0 decimals denominator
        data[6] = Data({
            description: "#6: SGD / USD * USD / PHP (no inversion): 8 decimals && 0 decimals",
            numeratorAnswer: int256(0.7361171 * 1e8),
            numeratorDecimals: 8,
            denominatorAnswer: int256(58),
            denominatorDecimals: 0,
            invertNumerator: false,
            invertDenominator: false,
            expectedAnswer: 4269479180,
            expectedFeedDecimals: 8
        });
        data[7] = Data({
            description: "#7: USDC / USD * PHP / USD (inverted denominator): 8 decimals & feed 18 decimals",
            // price of USDC in USD (1e8 precision)
            numeratorAnswer: int256(1e8),
            numeratorDecimals: 8,
            // this is the price of PHP in USD (1e8 precision)
            // therefore we need to invert it to get USD -> PHP
            // so that we have USDC -> PHP
            denominatorAnswer: int256(0.01711902 * 1e8),
            denominatorDecimals: 8,
            invertNumerator: false,
            invertDenominator: true,
            expectedAnswer: 58.41455877 * 1e8,
            expectedFeedDecimals: 8
        });
        data[8] = Data({
            description: "#8: USDC / USD * PHP / USD (inverted denominator): 0 decimals & feed 18 decimals",
            numeratorAnswer: int256(1),
            numeratorDecimals: 0,
            denominatorAnswer: int256(0.01711902 * 1e18),
            denominatorDecimals: 18,
            invertNumerator: false,
            invertDenominator: true,
            expectedAnswer: 58.41455877731318732 * 1e18,
            expectedFeedDecimals: 18
        });

        for (uint256 i = 0; i < data.length; i++) {
            Data memory d = data[i];

            if (keccak256(bytes(d.description)) == keccak256(bytes(""))) {
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

            assertEq(aggregator.decimals(), d.expectedFeedDecimals, d.description);

            (, int256 answer,,,) = aggregator.latestRoundData();
            assertEq(answer, d.expectedAnswer, d.description);
        }
    }
}
