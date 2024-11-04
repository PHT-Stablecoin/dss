
pragma solidity ^0.8.7;

import {console} from "forge-std/console.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

interface PipLike {
    function peek() external returns (bytes32, bool);
}

contract ChainlinkPip is PipLike {
    AggregatorV3Interface public dataFeed;
    
    constructor(address _dataFeed) {
        dataFeed = AggregatorV3Interface(_dataFeed);
    }

    function peek() external returns (bytes32 _answer, bool _has) {
        (
            /* uint80 roundID */,
            int256 answer,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = dataFeed.latestRoundData();

        _anwer = bytes32(answer);
        _has = true;
        
        return (_answer, _has);
    }
}