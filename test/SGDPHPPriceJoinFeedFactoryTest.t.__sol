pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {ChainlinkPip} from "./helpers/ChainlinkPip.sol";
import {PriceJoinFeedAggregator, AggregatorV3Interface} from "../script/factory/PriceJoinFeedAggregator.sol";
import {PriceJoinFeedFactory} from "../script/factory/PriceJoinFeedFactory.sol";

contract MockChainlinkPriceFeed is AggregatorV3Interface {
    int256 private _latestPrice;
    uint8 private _decimals;

    constructor(int256 initialPrice, uint8 decimals_) public {
        _latestPrice = initialPrice;
        _decimals = decimals_;
    }

    function latestRoundData()
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (1, _latestPrice, block.timestamp, block.timestamp, 1);
    }

    function decimals() external view override returns (uint8) {
        return _decimals;
    }

    function description() external view override returns (string memory) {
        return "Mock Price Feed";
    }

    function version() external view override returns (uint256) {
        return 1;
    }

    function getRoundData(
        uint80
    )
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (1, _latestPrice, block.timestamp, block.timestamp, 1);
    }

    function setPrice(int256 newPrice) external {
        _latestPrice = newPrice;
    }
}

contract SGDPHPPriceJoinFeedFactoryTest is Test {
    PriceJoinFeedFactory public factory;
    MockChainlinkPriceFeed public sgdUsdFeed;
    MockChainlinkPriceFeed public phpUsdFeed;
    PriceJoinFeedAggregator public sgdPhpAggregator;
    ChainlinkPip public pip;

    function setUp() public {
        factory = new PriceJoinFeedFactory();

        sgdUsdFeed = new MockChainlinkPriceFeed(7400000000, 8); // SGD/USD: 1 SGD = 0.74 USD
        phpUsdFeed = new MockChainlinkPriceFeed(1800000000, 8); // PHP/USD: 1 PHP = 0.018 USD

        (sgdPhpAggregator, pip) = factory.create(
            address(sgdUsdFeed),
            address(phpUsdFeed),
            false,
            false,
            "SGD/PHP Price Feed"
        );
    }

    function test_AdminFunctions() public {
        sgdPhpAggregator.file("decimals", uint(6));
        assertEq(sgdPhpAggregator.decimals(), uint(6));

        MockChainlinkPriceFeed newSgdFeed = new MockChainlinkPriceFeed(7500000000, 8);
        sgdPhpAggregator.file("numeratorFeed", address(newSgdFeed));
        assertEq(address(sgdPhpAggregator.numeratorFeed()), address(newSgdFeed));

        sgdPhpAggregator.file("invertNumerator", true);
        assertTrue(sgdPhpAggregator.invertNumerator());
    }

    function test_InitialPriceCalculation() public {
        (, int256 price, , , ) = sgdPhpAggregator.latestRoundData();

        int256 numerator = 7400000000; // 0.74 USD with 8 decimals
        int256 denominator = 1800000000; // 0.018 USD with 8 decimals
        int256 expected = (numerator * 10 ** 8) / denominator;

        assertEq(price, expected);
    }

    function test_updatePrices() public {
        sgdUsdFeed.setPrice(8000000000); // 0.80 USD
        phpUsdFeed.setPrice(2000000000); // 0.020 USD

        (, int256 price, , , ) = sgdPhpAggregator.latestRoundData();
        int256 expected = (8000000000 * 10 ** 8) / 2000000000;
        assertEq(price, expected);
    }

    function test_InvertedNumerator() public {
        (PriceJoinFeedAggregator invertedAggregator, ) = factory.create(
            address(sgdUsdFeed),
            address(phpUsdFeed),
            true, // invert numerator
            false,
            "USD/SGD-PHP/USD Price Feed"
        );

        (, int256 price, , , ) = invertedAggregator.latestRoundData();

        // Inverting 0.74 USD/SGD (7400000000)
        int256 numerator = int256(1e16); // Using 1e16 for 8 decimal precision
        int256 denominator = 7400000000;
        int256 inverseSgd = numerator / denominator;

        // expected result
        int256 expected = (inverseSgd * 10 ** 8) / 1800000000;

        assertEq(price, expected);
    }

    function test_InvertedDenominator() public {
        (PriceJoinFeedAggregator invertedAggregator, ) = factory.create(
            address(sgdUsdFeed),
            address(phpUsdFeed),
            false,
            true, // invert denominator
            "SGD/USD-USD/PHP Price Feed"
        );

        // Get the price
        (, int256 price, , , ) = invertedAggregator.latestRoundData();

        // 1. Original numerator = 7400000000 (0.74 USD)
        // 2. Original denominator = 1800000000 (0.018 USD)
        // 3. Invert denominator by doing (1e16/1800000000) from price feed join aggregator
        // 4. Multiply numerator by 1e8 and divides by inverted denominator

        // int256 inverted = (1e16) / 1800000000;
        // int256 expected = (7400000000 * 1e8);
        // 133200013320

        assertEq(price, 133200013320);
    }

    function test_BothInverted() public {
        // Create feed with both numerator and denominator inverted
        (PriceJoinFeedAggregator invertedAggregator, ) = factory.create(
            address(sgdUsdFeed),
            address(phpUsdFeed),
            true,
            true,
            "USD/SGD-USD/PHP Price Feed"
        );

        // SGD/USD = 0.74 USD (7400000000 with 8 decimals)
        // PHP/USD = 0.018 USD (1800000000 with 8 decimals)
        // inverse sgd = (1e16) / 7400000000
        // inverse php = (1e16) / 1800000000
        // (numerator * 1e16) / denominator

        (, int256 price, , , ) = invertedAggregator.latestRoundData();
        assertEq(price, 24324320);
    }

    function test_RevertOnZeroPrice() public {
        sgdUsdFeed.setPrice(0);
        vm.expectRevert("PriceJoinFeedAggregator/zero-price-feed");
        sgdPhpAggregator.latestRoundData();

        sgdUsdFeed.setPrice(7400000000);
        phpUsdFeed.setPrice(0);
        vm.expectRevert("PriceJoinFeedAggregator/zero-price-feed");
        sgdPhpAggregator.latestRoundData();
    }

    function test_AuthorizationChecks() public {
        address unauthorized = address(0x1);
        vm.startPrank(unauthorized);

        vm.expectRevert("ds-auth-unauthorized");
        sgdPhpAggregator.file("decimals", uint(6));

        vm.expectRevert("ds-auth-unauthorized");
        sgdPhpAggregator.file("numeratorFeed", address(0x1));

        vm.expectRevert("ds-auth-unauthorized");
        sgdPhpAggregator.file("invertNumerator", true);

        vm.stopPrank();
    }

    function test_InvalidFileParameters() public {
        vm.expectRevert("PriceJoinFeedAggregator/file-unrecognized-param");
        sgdPhpAggregator.file("invalid", uint(1));

        vm.expectRevert("PriceJoinFeedAggregator/file-unrecognized-param");
        sgdPhpAggregator.file("invalid", true);

        vm.expectRevert("PriceJoinFeedAggregator/file-unrecognized-param");
        sgdPhpAggregator.file("invalid", address(0x1));
    }

    function test_NullAddressCheck() public {
        vm.expectRevert("PriceJoinFeedAggregator/null-address");
        (sgdPhpAggregator, ) = factory.create(address(0), address(phpUsdFeed), false, false, "Invalid Feed");

        vm.expectRevert("PriceJoinFeedAggregator/null-address");
        (sgdPhpAggregator, ) = factory.create(address(sgdUsdFeed), address(0), false, false, "Invalid Feed");
    }
}
