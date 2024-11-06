
pragma solidity ^0.6.2;

interface PipLike {
    function peek() external returns (bytes32, bool);
}

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

contract ChainlinkPip is PipLike {
    AggregatorV3Interface public dataFeed;
    
    constructor(address _dataFeed) public {
        dataFeed = AggregatorV3Interface(_dataFeed);
    }

    /// Should convert answer (6 decimals) => answer (18 decimals)
    function peek() external override returns (bytes32 _answer, bool _has) {
        (
            /* uint80 roundID */,
            int256 answer,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = dataFeed.latestRoundData();

        if (answer < 0) {
            _has = false;
            return (_answer, _has);
        }

        uint8 decimals = dataFeed.decimals();
        _answer = bytes32((uint256(answer) * 1e18 / (10 ** uint256(decimals))));
        _has = true;

        return (_answer, _has);
    }
}