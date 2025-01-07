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

interface IThingAdmin {
    // --- Administration ---
    function file(bytes32 what, address data) external;
    function file(bytes32 what, bool data) external;
    function file(bytes32 what, uint256 data) external;
}

contract PriceJoinFeedAggregator is AggregatorV3Interface, IThingAdmin, DSThing {
    // Ex: Feeds for XSGD/USD - PHP/USD
    AggregatorV3Interface public numeratorFeed;
    AggregatorV3Interface public denominatorFeed;

    bool public invertNumerator;
    bool public invertDenominator;

    // --- Auth ---
    mapping(address => uint256) public wards;

    function rely(address guy) external auth {
        wards[guy] = 1;
    }

    function deny(address guy) external auth {
        wards[guy] = 0;
    }

    string public override description = ""; // XSGD/USD-PHP/USD
    uint8 public override decimals = 8;
    uint256 public override version = 0;

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

        wards[msg.sender] = 1;

        numeratorFeed = AggregatorV3Interface(_numeratorFeed);
        denominatorFeed = AggregatorV3Interface(_denominatorFeed);

        invertNumerator = _invertNumerator;
        invertDenominator = _invertDenominator;
        description = _description;
    }

    // --- Administration ---
    function file(bytes32 what, address data) external override auth {
        if (what == "numeratorFeed") numeratorFeed = AggregatorV3Interface(data);
        else if (what == "denominatorFeed") denominatorFeed = AggregatorV3Interface(data);
        else revert("PriceJoinFeedAggregator/file-unrecognized-param");
    }

    function file(bytes32 what, bool data) external override auth {
        if (what == "invertNumerator") invertNumerator = data;
        else if (what == "invertDenominator") invertDenominator = data;
        else revert("PriceJoinFeedAggregator/file-unrecognized-param");
    }

    function file(bytes32 what, uint256 data) external override auth {
        if (what == "decimals") decimals = uint8(data);
        else revert("PriceJoinFeedAggregator/file-unrecognized-param");
    }

    function getRoundData(uint80 _roundId)
        external
        view
        override
        returns (uint80, int256 _answer, uint256 _startedAt, uint256 _updatedAt, uint80 _answeredInRound)
    {
        return _getAnswer();
    }

    function latestRoundData()
        external
        view
        override
        returns (uint80 _roundId, int256 _answer, uint256 _startedAt, uint256 _updatedAt, uint80 _answeredInRound)
    {
        return _getAnswer();
    }

    function _getAnswer()
        internal
        view
        returns (uint80 _roundId, int256 _answer, uint256 _startedAt, uint256 _updatedAt, uint80 _answeredInRound)
    {
        (
            uint80 _numRoundId,
            int256 _numAnswer,
            uint256 _numStartedAt,
            uint256 _numUpdatedAt,
            uint80 _numAnsweredInRound
        ) = numeratorFeed.latestRoundData();

        (
            uint80 _denomRoundId,
            int256 _denomAnswer,
            uint256 _denomStartedAt,
            uint256 _denomUpdatedAt,
            uint80 _denomAnsweredInRound
        ) = denominatorFeed.latestRoundData();

        // TODO: chainlink stale data check
        require(_numAnswer > 0 && _denomAnswer > 0, "PriceJoinFeedAggregator/zero-price-feed");

        {
            // Handle feed inversions with 8 decimals
            int256 adjustedNumAnswer = invertNumerator ? _calculateInverse(_numAnswer) : _numAnswer;
            int256 adjustedDenomAnswer = invertDenominator ? _calculateInverse(_denomAnswer) : _denomAnswer;

            // Calculate final answer maintaining 8 decimal precision
            _answer = (adjustedNumAnswer * 1e8) / adjustedDenomAnswer;
        }

        // Checks the most recent/latest information bet 2 feeds
        _roundId = _numRoundId > _denomRoundId ? _numRoundId : _denomRoundId;
        _startedAt = _numStartedAt > _denomStartedAt ? _numStartedAt : _denomStartedAt;
        _updatedAt = _numUpdatedAt > _denomUpdatedAt ? _numUpdatedAt : _denomUpdatedAt;
        _answeredInRound = _numAnsweredInRound > _denomAnsweredInRound ? _numAnsweredInRound : _denomAnsweredInRound;
    }

    function _calculateInverse(int256 price) internal pure returns (int256) {
        return (1e16) / price; // Using 1e16 (1e8 * 1e8) for 8 decimals precision
    }
}
