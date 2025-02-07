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

    mapping(address => bool) public feedRegistry;

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
    ) external auth returns (PriceJoinFeedAggregator feed) {
        feed =
            new PriceJoinFeedAggregator(numeratorFeed, denominatorFeed, invertNumerator, invertDenominator, description);

        feedRegistry[address(feed)] = true;

        // pass on the authority to any instances created from this factory
        feed.setAuthority(authority);

        // Transfer feed ownership to caller
        feed.setOwner(msg.sender);

        emit PriceFeedJoinCreated(
            numeratorFeed, invertNumerator, denominatorFeed, invertDenominator, description, msg.sender
        );
    }

    function getFeedInfo(address feed) external view returns (PriceFeedInfo memory info) {
        require(feed != address(0), "PriceFeedJoinFactory/invalid-address");
        require(feedRegistry[feed], "PriceFeedJoinFactory/feed-not-registered");

        PriceJoinFeedAggregator feedInstance = PriceJoinFeedAggregator(feed);

        return PriceFeedInfo({
            numeratorFeed: address(feedInstance.numeratorFeed()),
            invertNumerator: feedInstance.invertNumerator(),
            denominatorFeed: address(feedInstance.denominatorFeed()),
            invertDenominator: feedInstance.invertDenominator(),
            description: feedInstance.description()
        });
    }
}
