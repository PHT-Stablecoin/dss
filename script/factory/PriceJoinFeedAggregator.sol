pragma solidity >=0.6.12;

import {DSThing} from "ds-thing/thing.sol";

interface AggregatorV3Interface {
  function decimals() external view returns (uint8);

  function description() external view returns (string memory);

  function version() external view returns (uint256);

  function getRoundData(
    uint80 _roundId
  ) external view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);

  function latestRoundData()
    external
    view
    returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

contract PriceJoinFeedAggregator is AggregatorV3Interface, DSThing {
    // Ex: Feeds for XSGD/USD - PHP/USD
    AggregatorV3Interface public numeratorFeed;
    AggregatorV3Interface public denominatorFeed;

    bool public invertNumerator;
    bool public invertDenominator;

    // --- Auth ---
    mapping(address => uint) public wards;
    function rely(address guy) external auth {
        wards[guy] = 1;
    }
    function deny(address guy) external auth {
        wards[guy] = 0;
    }

    string public override description = ""; // XSGD/PHP-PHP/USD
    uint8 public override decimals = 6;
    uint256 public override version = 0;

    // --- Init ---
    constructor(
        address _numeratorFeed,
        address _denominatorFeed,
        bool _invertNumerator,
        bool _invertDenominator,
        string memory _description
    ) public {
        wards[msg.sender] = 1;

        numeratorFeed = AggregatorV3Interface(_numeratorFeed);
        denominatorFeed = AggregatorV3Interface(_denominatorFeed);
        decimals = numeratorFeed.decimals();
        require(
            decimals == denominatorFeed.decimals(),
            "PriceJoinFeedAggregator/constructor-invalid-decimals");
        
        invertNumerator = _invertNumerator;
        invertDenominator = _invertDenominator;
        description = _description;
    }

    // --- Administration ---
    function file(bytes32 what, address data) external auth {
        if (what == "numeratorFeed") numeratorFeed = AggregatorV3Interface(data);
        if (what == "denominatorFeed") denominatorFeed = AggregatorV3Interface(data);
        else revert("PriceJoinFeedAggregator/file-unrecognized-param");
    }

    function file(bytes32 what, bool data) external auth {
        if (what == "invertNumerator") invertNumerator = data;
        if (what == "invertDenominator") invertDenominator = data;
        else revert("PriceJoinFeedAggregator/file-unrecognized-param");
    }

    function file(bytes32 what, uint data) external auth {
        if (what == "decimals") decimals = uint8(data);
        else revert("PriceJoinFeedAggregator/file-unrecognized-param");
    }

    function getRoundData(
        uint80 _roundId
    )
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

    function _getAnswer() internal view returns (uint80 _roundId, int256 _answer, uint256 _startedAt, uint256 _updatedAt, uint80 _answeredInRound) {
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

        {
            // Handle feed inversions with 6 decimals
            int256 adjustedNumAnswer = invertNumerator ? _calculateInverse(_numAnswer) : _numAnswer;
            int256 adjustedDenomAnswer = invertDenominator ? _calculateInverse(_denomAnswer) : _denomAnswer;

            // Calculate final answer maintaining 6 decimal precision
            _answer = (adjustedNumAnswer * 1e6) / adjustedDenomAnswer;
        }

        // Checks the most recent/latest information bet 2 feeds
        _roundId = _numRoundId > _denomRoundId ? _numRoundId : _denomRoundId;
        _startedAt = _numStartedAt > _denomStartedAt ? _numStartedAt : _denomStartedAt;
        _updatedAt = _numUpdatedAt > _denomUpdatedAt ? _numUpdatedAt : _denomUpdatedAt;
        _answeredInRound = _numAnsweredInRound > _denomAnsweredInRound ? _numAnsweredInRound : _denomAnsweredInRound;
    }

    function _calculateInverse(int256 price) internal pure returns (int256) {
      return (1e12) / price; // Using 1e12 (1e6 * 1e6) for 6 decimals precision
    }
}
