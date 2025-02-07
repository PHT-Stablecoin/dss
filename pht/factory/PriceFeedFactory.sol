pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import {PriceFeedAggregator} from "./PriceFeedAggregator.sol";
import {DSAuth} from "ds-auth/auth.sol";

contract PriceFeedFactory is DSAuth {
    struct PriceFeedInfo {
        address feedAddress; // Address of the deployed price feed
        string description; // Description of what this feed represents
        uint8 decimals; // Decimal precision of the feed
        bool exists; // Exists flag for registration check
    }

    mapping(address => bool) public feedRegistry;

    event PriceFeedCreated(address indexed feed, string description, uint8 decimals, address indexed creator);

    function create(uint8 decimals, int256 initialAnswer, string memory description)
        external
        auth
        returns (PriceFeedAggregator feed)
    {
        feed = new PriceFeedAggregator();
        feed.file("description", description);
        feed.file("decimals", uint256(decimals));
        feed.file("answer", initialAnswer);

        feedRegistry[address(feed)] = true;

        // pass on the authority to any instances created from this factory
        feed.setAuthority(authority);

        // Transfer feed ownership to caller
        feed.setOwner(msg.sender);

        emit PriceFeedCreated(address(feed), description, decimals, msg.sender);
    }

    function getFeedInfo(address feed) external view returns (PriceFeedInfo memory info) {
        require(feed != address(0), "PriceFeedFactory/invalid-address");
        require(feedRegistry[feed], "PriceFeedFactory/feed-not-registered");

        PriceFeedAggregator feedInstance = PriceFeedAggregator(feed);

        return PriceFeedInfo({
            feedAddress: feed,
            description: feedInstance.description(),
            decimals: feedInstance.decimals(),
            exists: true
        });
    }
}
