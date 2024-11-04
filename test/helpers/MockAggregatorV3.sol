pragma solidity ^0.8.7;

import {console} from "forge-std/console.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract MockAggregatorV3 is AggregatorV3Interface, DSThing {

    // --- Auth ---
    mapping(address => uint) public wards;
    function rely(address guy) external auth {
        wards[guy] = 1;
    }
    function deny(address guy) external auth {
        wards[guy] = 0;
    }

    modifier auth() {
        require(wards[msg.sender] == 1, "MockAggregatorV3/not-authorized");
        _;
    }

    uint256 public live;

    // --- Init ---
    constructor() public {
        wards[msg.sender] = 1;
        live = 1;
    }

    // --- Administration ---
    function file(bytes32 ilk, bytes32 what, address pip_) external auth {
        require(live == 1, "MockAggregatorV3/not-live");
        if (what == "pip") ilks[ilk].pip = PipLike(pip_);
        else revert("MockAggregatorV3/file-unrecognized-param");
    }
    function file(bytes32 what, uint data) external auth {
        require(live == 1, "MockAggregatorV3/not-live");
        if (what == "par") par = data;
        else revert("MockAggregatorV3/file-unrecognized-param");
    }
    function file(bytes32 ilk, bytes32 what, uint data) external auth {
        require(live == 1, "MockAggregatorV3/not-live");
        if (what == "mat") ilks[ilk].mat = data;
        else revert("MockAggregatorV3/file-unrecognized-param");
    }

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