pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import {PriceJoinFeedAggregator, AggregatorV3Interface} from "./PriceJoinFeedAggregator.sol";
import {ChainlinkPip} from "../helpers/ChainlinkPip.sol";
import {DSAuth} from "ds-auth/auth.sol";

contract PriceJoinFeedFactory is DSAuth {
    struct PriceFeedInfo {
        address numeratorFeed; // (optional)
        bool invertNumerator;
        address denominatorFeed;
        bool invertDenominator;
        string description;
    }

    mapping(address => PriceFeedInfo) public feedRegistry;

    event PriceFeedJoinCreated(
        address numeratorFeed,
        bool invertNumerator,
        address denominatorFeed,
        bool invertDenominator,
        string description,
        address indexed creator
    );

    function create(
        address numeratorFeed,
        address denominatorFeed,
        bool invertNumerator,
        bool invertDenominator,
        string memory description
    ) external returns (PriceJoinFeedAggregator feed) {
        feed = new PriceJoinFeedAggregator(
            numeratorFeed,
            denominatorFeed,
            invertNumerator,
            invertDenominator,
            description
        );

        feedRegistry[address(feed)] = PriceFeedInfo({
            numeratorFeed: numeratorFeed,
            invertNumerator: invertNumerator,
            denominatorFeed: denominatorFeed,
            invertDenominator: invertDenominator,
            description: description
        });

        // Transfer feed ownership to caller
        feed.setOwner(msg.sender);

        emit PriceFeedJoinCreated(
            numeratorFeed,
            invertNumerator,
            denominatorFeed,
            invertDenominator,
            description,
            msg.sender
        );
    }

    function getFeedInfo(address feed) external view returns (PriceFeedInfo memory info) {
        require(feed != address(0), "PriceFeedJoinFactory/invalid-address");
        return feedRegistry[feed];
    }
}
