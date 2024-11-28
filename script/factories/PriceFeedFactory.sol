pragma solidity ^0.6.12;

import {PriceFeedAggregator} from "./PriceFeedAggregator.sol";
import {ChainlinkPip} from "../../test/helpers/ChainlinkPip.sol";
import {DSAuth} from "ds-auth/auth.sol";

contract PriceFeedFactory is DSAuth {
    struct PriceFeedInfo {
        address feedAddress; // Address of the deployed price feed
        string description; // Description of what this feed represents
        uint8 decimals; // Decimal precision of the feed
        bool exists; // Exists flag for registration check
    }

    mapping(address => PriceFeedInfo) public feedRegistry;

    event PriceFeedCreated(address indexed feed, string description, uint8 decimals, address indexed creator);

    function createPriceFeed(
        uint8 decimals,
        int initialAnswer,
        string description
    ) external auth returns (address feedAddress, address chainlinkPip) {
        PriceFeedAggregator feed = new PriceFeedAggregator();
        feedAddress = address(feed);

        // Price feed decimals and initial price
        feed.file("decimals", decimals);

        if (initialAnswer > 0) {
            feed.file("answer", initialAnswer);
        }

        chainlinkPip = new ChainlinkPip(feedAddress);

        feedRegistry[feedAddress] = PriceFeedInfo({
            feedAddress: feedAddress,
            description: description,
            decimals: decimals,
            exists: true
        });

        // Transfer feed ownership to caller
        feed.rely(msg.sender);
        feed.deny(address(this));

        emit PriceFeedCreated(feedAddress, description, decimals, msg.sender);
    }

    function getFeedInfo(address feed) external view returns (PriceFeedInfo memory info) {
        require(feed != address(0), "PriceFeedFactory/invalid-address");
        require(feedRegistry[feed].exists, "PriceFeedFactory/feed-not-registered");
        return feedRegistry[feed];
    }
}
