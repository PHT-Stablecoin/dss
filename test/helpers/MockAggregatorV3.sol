pragma solidity >=0.6.12;
pragma experimental ABIEncoderV2;

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

contract MockAggregatorV3 is AggregatorV3Interface, DSThing {
    // --- Auth ---
    mapping(address => uint256) public wards;

    function rely(address guy) external auth {
        wards[guy] = 1;
    }

    function deny(address guy) external auth {
        wards[guy] = 0;
    }

    uint256 public override version = 0;
    string public override description = "";
    uint8 public override decimals = 6;

    int256 internal answer = 0;
    uint256 internal live = 0;

    // --- Init ---
    constructor() public {
        wards[msg.sender] = 1;
        live = 1;
    }

    // --- Administration ---
    function file(bytes32 what, uint256 data) external auth {
        require(live == 1, "MockAggregatorV3/not-live");
        if (what == "decimals") decimals = uint8(data);
        else revert("MockAggregatorV3/file-unrecognized-param");
    }

    function file(bytes32 what, int256 data) external auth {
        require(live == 1, "MockAggregatorV3/not-live");
        if (what == "answer") answer = data;
        else revert("MockAggregatorV3/file-unrecognized-param");
    }

    function getRoundData(uint80 _roundId)
        external
        view
        override
        returns (uint80 roundId, int256 _answer, uint256 _startedAt, uint256 _updatedAt, uint80 _answeredInRound)
    {
        roundId = _roundId;
        _answer = answer;
        _startedAt = block.timestamp;
        _updatedAt = block.timestamp;
        _answeredInRound = _roundId;
    }

    function latestRoundData()
        external
        view
        override
        returns (uint80 _roundId, int256 _answer, uint256 _startedAt, uint256 _updatedAt, uint80 _answeredInRound)
    {
        _answer = answer;
        _roundId = 1;
        _startedAt = block.timestamp;
        _updatedAt = block.timestamp;
        _answeredInRound = 1;
    }
}
