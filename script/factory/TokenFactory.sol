pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import {ConfigurableDSToken} from "./ConfigurableDSToken.sol";
import {DSToken} from "ds-token/token.sol";
import {DSAuth} from "ds-auth/auth.sol";

contract TokenFactory is DSAuth {
    enum TokenType {
        Standard,
        Configurable
    }

    struct TokenInfo {
        address tokenAddress;
        string name;
        string symbol;
        uint8 decimals;
        uint256 maxSupply;
        TokenType tokenType;
    }

    mapping(address => TokenInfo) public tokenRegistry;

    event StandardTokenCreated(address indexed token, string name, string symbol);
    event ConfigurableTokenCreated(
        address indexed token,
        string name,
        string symbol,
        uint8 decimals,
        uint256 maxSupply
    );

    function createStandardToken(
        string memory symbol,
        string memory name
    ) external auth returns (address tokenAddress) {
        DSToken token = new DSToken(symbol);
        tokenAddress = address(token);

        token.setName(name);
        token.setOwner(msg.sender);

        _registerToken(
            tokenAddress,
            name,
            symbol,
            18, // Standard decimals
            0, // No supply cap
            TokenType.Standard
        );

        emit StandardTokenCreated(tokenAddress, name, symbol);
    }

    function createConfigurableToken(
        string memory symbol,
        string memory name,
        uint8 decimals,
        uint256 maxSupply
    ) external auth returns (address tokenAddress) {
        ConfigurableDSToken token = new ConfigurableDSToken(symbol, name, decimals, maxSupply);
        tokenAddress = address(token);

        token.setName(name);
        token.setOwner(msg.sender);

        _registerToken(tokenAddress, name, symbol, decimals, maxSupply, TokenType.Configurable);

        emit ConfigurableTokenCreated(tokenAddress, name, symbol, decimals, maxSupply);
    }

    function _registerToken(
        address tokenAddress,
        string memory name,
        string memory symbol,
        uint8 decimals,
        uint256 maxSupply,
        TokenType tokenType
    ) private {
        tokenRegistry[tokenAddress] = TokenInfo({
            tokenAddress: tokenAddress,
            name: name,
            symbol: symbol,
            decimals: decimals,
            maxSupply: maxSupply,
            tokenType: tokenType
        });
    }

    function getTokenInfo(address token) external view returns (TokenInfo memory) {
        require(tokenRegistry[token].tokenAddress == token, "TokenFactory/token-not-registered");
        return tokenRegistry[token];
    }
}
