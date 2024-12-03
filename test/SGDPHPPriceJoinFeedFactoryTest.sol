pragma solidity >=0.6.12;
pragma experimental ABIEncoderV2;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {ChainlinkPip} from "./helpers/ChainlinkPip.sol";
import {MockAggregatorV3} from "./helpers/MockAggregatorV3.sol";
import {PriceJoinFeedAggregator} from "../script/factory/PriceJoinFeedAggregator.sol";
import {PriceJoinFeedFactory} from "../script/factory/PriceJoinFeedFactory.sol";

interface AggregatorV3Interface {
    function decimals() external view returns (uint8);
    function description() external view returns (string memory);
    function version() external view returns (uint256);
    function getRoundData(
        uint80 _roundId
    )
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

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

        // SGD/USD: 1 SGD = 0.74 USD (sample rate)
        sgdUsdFeed = new MockChainlinkPriceFeed(74 * 10 ** 8, 8);

        // PHP/USD: 1 PHP = 0.018 USD (sample rate)
        phpUsdFeed = new MockChainlinkPriceFeed(18 * 10 ** 8, 8);

        // Create the price join feed aggregator
        // We wanna alculate SGD/PHP
        (sgdPhpAggregator, pip) = factory.create(
            address(sgdUsdFeed), // Numerator feed
            address(phpUsdFeed), // Denominator feed
            false, // don't invert numerator
            false, // don't invert denominator
            "SGD/PHP Price Feed"
        );
    }

    function test_InitialPriceCalculation() public {
        // Expected calculation: (SGD/USD) / (PHP/USD) = SGD/PHP
        // 0.74 / 0.018 = 41.11 PHP per SGD
        (, int256 price, , , ) = sgdPhpAggregator.latestRoundData();

        assertEq(price, (74 * 10 ** 8) / 18);
    }
}
