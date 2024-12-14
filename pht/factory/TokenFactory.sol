pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import {ConfigurableDSToken} from "../token/ConfigurableDSToken.sol";
import {DSToken} from "ds-token/token.sol";
import {DSAuth} from "ds-auth/auth.sol";

contract TokenFactory {
    event StandardTokenCreated(
        address indexed token,
        string name,
        string symbol
    );

    event ConfigurableTokenCreated(
        address indexed token,
        string name,
        string symbol,
        uint8 decimals,
        uint256 maxSupply
    );

    function newToken(
        string memory symbol,
        string memory name
    ) external returns (DSToken token) {
        token = new DSToken(symbol);
        token.setName(name);
        token.setOwner(msg.sender);

        emit StandardTokenCreated(address(token), name, symbol);
    }

    function newToken(
        string memory symbol,
        string memory name,
        uint8 decimals,
        uint256 maxSupply
    ) external returns (ConfigurableDSToken token) {
        token = new ConfigurableDSToken(symbol, name, decimals, maxSupply);
        token.setName(name);
        token.setOwner(msg.sender);

        emit ConfigurableTokenCreated(address(token), name, symbol, decimals, maxSupply);
    }
}
