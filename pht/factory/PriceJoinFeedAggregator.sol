pragma solidity >=0.6.12;

import {DSThing} from "ds-thing/thing.sol";

interface AggregatorV3Interface {
    function decimals() external view returns (uint8);

    function description() external view returns (string memory);

    function version() external view returns (uint256);

    function getRoundData(uint80 _roundId)
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

interface IERC20Metadata {
    function decimals() external view returns (uint8);
}

interface IThingAdmin {
    // --- Administration ---
    function file(bytes32 what, uint256 data) external;
}

/**
 * @title PriceJoinFeedAggregator
 * @notice This contract is used to join two price feeds together. For example, if you want to join
 * SGD/USD and PHP/USD to get SGD/PHP, you can use this contract as such:
 *
 * PriceJoinFeedAggregator(address(SGD/USD), address(PHP/USD), false, true, "SGD/PHP");
 *
 * This will return the price of SGD in PHP.
 * NB: note the second bool is true, which means we invert the denominator.
 *
 * @dev This contract uses round down for all calculations, because this oracle is used for pricing
 * collateral.
 *
 * @dev This contract supports any price feed tokens with 0 <= decimals <= 18.
 */
contract PriceJoinFeedAggregator is AggregatorV3Interface, IThingAdmin, DSThing {
    // Ex: Feeds for XSGD/USD - PHP/USD
    AggregatorV3Interface public immutable numeratorFeed;
    AggregatorV3Interface public immutable denominatorFeed;

    bool public immutable invertNumerator;
    bool public immutable invertDenominator;

    uint256 public constant ONE = 1e18;
    string public override description;
    // feed decimals
    uint8 public immutable override decimals;
    uint256 public constant override version = 1;

    uint256 public live;

    // private variables
    uint256 private immutable _feedScalingFactor;
    uint256 private immutable _numeratorScalingFactor;
    uint256 private immutable _denominatorScalingFactor;

    // --- Init ---
    constructor(
        address _numeratorFeed,
        address _denominatorFeed,
        bool _invertNumerator,
        bool _invertDenominator,
        string memory _description
    ) public {
        require(_numeratorFeed != address(0), "PriceJoinFeedAggregator/null-address");
        require(_denominatorFeed != address(0), "PriceJoinFeedAggregator/null-address");

        live = 1;

        uint8 numeratorDecimals;
        uint8 denominatorDecimals;
        uint256 numeratorScalingFactor;
        uint256 denominatorScalingFactor;

        (numeratorDecimals, numeratorScalingFactor) = _computeScalingFactor(_numeratorFeed);
        (denominatorDecimals, denominatorScalingFactor) = _computeScalingFactor(_denominatorFeed);

        // use the smaller scaling factor - this is the opposite of the decimals
        // scaling factor is used to scale down the price feed, therefore we pick
        // the smaller scaling factor to scale down the least
        _feedScalingFactor =
            numeratorScalingFactor < denominatorScalingFactor ? numeratorScalingFactor : denominatorScalingFactor;

        decimals = numeratorDecimals > denominatorDecimals ? numeratorDecimals : denominatorDecimals;

        numeratorFeed = AggregatorV3Interface(_numeratorFeed);
        denominatorFeed = AggregatorV3Interface(_denominatorFeed);

        _numeratorScalingFactor = numeratorScalingFactor;
        _denominatorScalingFactor = denominatorScalingFactor;
        invertNumerator = _invertNumerator;
        invertDenominator = _invertDenominator;
        description = _description;
    }

    function file(bytes32 what, uint256 data) external override auth {
        if (what == "live") {
            live = data;
        } else {
            revert("PriceJoinFeedAggregator/file-unrecognized-2-param");
        }
    }

    function getRoundData(uint80 /*_roundId*/ )
        external
        view
        override
        returns (uint80 roundId, int256 _answer, uint256 _startedAt, uint256 _updatedAt, uint80 _answeredInRound)
    {
        require(live == 1, "PriceJoinFeedAggregator/not-live");
        return _getAnswer();
    }

    function latestRoundData()
        external
        view
        override
        returns (uint80 _roundId, int256 _answer, uint256 _startedAt, uint256 _updatedAt, uint80 _answeredInRound)
    {
        require(live == 1, "PriceJoinFeedAggregator/not-live");
        return _getAnswer();
    }

    function _getAnswer()
        internal
        view
        returns (uint80 _roundId, int256 _answer, uint256 _startedAt, uint256 _updatedAt, uint80 _answeredInRound)
    {
        int256 numAnswerScaled;
        int256 denomAnswerScaled;
        {
            int256 _numAnswer;
            int256 _denomAnswer;
            (_numAnswer, _denomAnswer, _roundId, _startedAt, _updatedAt, _answeredInRound) = _validatePriceFeeds();
            numAnswerScaled = int256(_toScaled18RoundDown(uint256(_numAnswer), _numeratorScalingFactor));
            denomAnswerScaled = int256(_toScaled18RoundDown(uint256(_denomAnswer), _denominatorScalingFactor));
        }

        int256 adjustedNumAnswer = invertNumerator ? int256(1e36) / numAnswerScaled : numAnswerScaled;
        int256 adjustedDenomAnswer = invertDenominator ? int256(1e36) / denomAnswerScaled : denomAnswerScaled;

        // Calculate final answer maintaining decimal precision
        _answer = int256(_toRawRoundDown(uint256(adjustedNumAnswer * adjustedDenomAnswer) / ONE, _feedScalingFactor));
    }

    function _validatePriceFeeds()
        internal
        view
        returns (
            int256 _numAnswer,
            int256 _denomAnswer,
            uint80 _roundId,
            uint256 _startedAt,
            uint256 _updatedAt,
            uint80 _answeredInRound
        )
    {
        (
            uint80 _numRoundId,
            // NB: no underscore in the variable name to avoid shadowing the return variable
            int256 numAnswer,
            uint256 _numStartedAt,
            uint256 _numUpdatedAt,
            uint80 _numAnsweredInRound
        ) = numeratorFeed.latestRoundData();

        (
            uint80 _denomRoundId,
            // NB: no underscore in the variable name to avoid shadowing the return variable
            int256 denomAnswer,
            uint256 _denomStartedAt,
            uint256 _denomUpdatedAt,
            uint80 _denomAnsweredInRound
        ) = denominatorFeed.latestRoundData();

        // sanity checks
        require(_numAnsweredInRound >= _numRoundId, "PriceJoinFeedAggregator/round-incomplete");
        require(_denomAnsweredInRound >= _denomRoundId, "PriceJoinFeedAggregator/round-incomplete");
        require(_numUpdatedAt > 0, "PriceJoinFeedAggregator/round-incomplete");
        require(_denomUpdatedAt > 0, "PriceJoinFeedAggregator/round-incomplete");
        require(numAnswer > 0 && denomAnswer > 0, "PriceJoinFeedAggregator/lte-zero-price-feed");

        // NB: we DO NOT perform any heartbeat staleness checks here on purpose
        // because liquididation auctions would stop working
        // therefore we monitor Price feed aggregators staleness in off-chain
        // scripts and alert on it

        // assign the return variables
        _numAnswer = numAnswer;
        _denomAnswer = denomAnswer;

        // Checks the most recent/latest information between the 2 feeds
        _roundId = _numRoundId > _denomRoundId ? _numRoundId : _denomRoundId;
        _startedAt = _numStartedAt > _denomStartedAt ? _numStartedAt : _denomStartedAt;
        _updatedAt = _numUpdatedAt > _denomUpdatedAt ? _numUpdatedAt : _denomUpdatedAt;
        _answeredInRound = _numAnsweredInRound > _denomAnsweredInRound ? _numAnsweredInRound : _denomAnsweredInRound;
    }

    /**
     * @notice Applies `scalingFactor` to `amount`.
     * @dev This may result in a larger or equal value, depending on whether it needed scaling or not.
     * The result is rounded down.
     *
     * @param amount Amount to be scaled up to 18 decimals
     * @param scalingFactor The token decimal scaling factor
     * @return result The final 18-decimal precision result, rounded down
     */
    function _toScaled18RoundDown(uint256 amount, uint256 scalingFactor) internal pure returns (uint256) {
        return _mulDown(amount, scalingFactor * ONE);
    }

    function _computeScalingFactor(address token) internal view returns (uint8 decimals, uint256 scalingFactor) {
        uint256 tokenDecimals = IERC20Metadata(token).decimals();
        require(tokenDecimals <= 18, "PriceJoinFeedAggregator/token-decimals-gt-18");

        uint256 decimalsDifference = 18 - tokenDecimals;
        return (uint8(tokenDecimals), 10 ** decimalsDifference);
    }

    /**
     * @notice Multiplies two unsigned integers that are scaled to 18 decimals, rounding down.
     */
    function _mulDown(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) return 0;
        uint256 product = a * b;
        require(product / a == b, "PriceJoinFeedAggregator/_mulDown: multiplication overflow");
        return product / ONE;
    }

    /**
     * @notice Reverses the `scalingFactor` applied to `amount`.
     * @dev This may result in a smaller or equal value, depending on whether it needed scaling or not. The result
     * is rounded down.
     *
     * @param amount Amount to be scaled down to native token decimals
     * @param scalingFactor The token decimal scaling factor
     * @return result The final native decimal result, rounded down
     */
    function _toRawRoundDown(uint256 amount, uint256 scalingFactor) internal pure returns (uint256) {
        return _divDown(amount, scalingFactor * ONE);
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     */
    function _divDown(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "PriceJoinFeedAggregator/_divDown: division by zero");
        uint256 aInflated = a * ONE;

        return aInflated / b;
    }
}
