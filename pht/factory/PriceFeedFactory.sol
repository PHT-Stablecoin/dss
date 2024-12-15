pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import {PriceFeedAggregator} from "./PriceFeedAggregator.sol";
import {ChainlinkPip} from "../helpers/ChainlinkPip.sol";
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

    function create(
        uint8 decimals,
        int initialAnswer,
        string memory description
    ) external returns (PriceFeedAggregator feed) {
        feed = new PriceFeedAggregator();

        feedRegistry[address(feed)] = PriceFeedInfo({
            feedAddress: address(feed),
            description: description,
            decimals: decimals,
            exists: true
        });

        feed.file("decimals", uint(decimals));
        feed.file("answer", initialAnswer);
        // Transfer feed ownership to caller
        feed.setOwner(msg.sender);

        emit PriceFeedCreated(address(feed), description, decimals, msg.sender);
    }

    function getFeedInfo(address feed) external view returns (PriceFeedInfo memory info) {
        require(feed != address(0), "PriceFeedFactory/invalid-address");
        require(feedRegistry[feed].exists, "PriceFeedFactory/feed-not-registered");
        return feedRegistry[feed];
    }
}
