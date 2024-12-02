pragma solidity >=0.6.12;

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

contract AggregatorAdapter2Feeds is AggregatorV3Interface, DSThing {
    // Ex: Feeds for XSGD/USD - PHP/USD
    AggregatorV3Interface public immutable numeratorFeed;
    AggregatorV3Interface public immutable denominatorFeed;

    bool public immutable invertNumerator;
    bool public immutable invertDenominator;

    // --- Auth ---
    mapping(address => uint) public wards;
    function rely(address guy) external auth {
        wards[guy] = 1;
    }
    function deny(address guy) external auth {
        wards[guy] = 0;
    }

    uint256 public override version = 0;
    string public override description = ""; // XSGD/PHP-PHP/USD
    uint8 public override decimals = 6;

    int256 internal answer = 0;
    uint internal live = 0;

    // --- Init ---
    constructor(
        address _numeratorFeed,
        address _denominatorFeed,
        bool _invertNumerator,
        bool _invertDenominator
        string memory _description
    ) public {
        wards[msg.sender] = 1;
        live = 1;

        numeratorFeed = AggregatorV3Interface(_numeratorFeed);
        denominatorFeed = AggregatorV3Interface(_denominatorFeed);
        invertNumerator = _invertNumerator;
        invertDenominator = _invertDenominator;
        description = _description;
    }

    // --- Administration ---
    function file(bytes32 what, address data) external auth {
        require(live == 1, "AggregatorAdapter2Feeds/not-live");
        if (what == "numeratorFeed") numeratorFeed = data);
        if (what == "denominatorFeed") denominatorFeed = data);
        else revert("AggregatorAdapter2Feeds/file-unrecognized-param");
    }

    function file(bytes32 what, bool data) external auth {
        require(live == 1, "AggregatorAdapter2Feeds/not-live");
        if (what == "invertNumerator") invertNumerator = data);
        if (what == "invertDenominator") invertDenominator = data);
        else revert("AggregatorAdapter2Feeds/file-unrecognized-param");
    }

    function file(bytes32 what, uint data) external auth {
        require(live == 1, "AggregatorAdapter2Feeds/not-live");
        if (what == "decimals") decimals = uint8(data);
        else revert("AggregatorAdapter2Feeds/file-unrecognized-param");
    }

    function file(bytes32 what, int256 data) external auth {
        require(live == 1, "AggregatorAdapter2Feeds/not-live");
        if (what == "answer") answer = data;
        else revert("AggregatorAdapter2Feeds/file-unrecognized-param");
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
            uint256 _numStartedA,
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

        // Handle feed inversions with 6 decimals
        int256 adjustedNumPrice = invertNumerator ? _calculateInverse(_numAnswer) : _numPrice;
        int256 adjustedDenomPrice invertDenominator ? _calculateInverse(_denomAnswer) : _denomAnswer;

        // Calculate final answer maintaining 6 decimal precision
        _answer = (adjustedNumAnswer * 1e6) / adjustedDenomPrice;

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
