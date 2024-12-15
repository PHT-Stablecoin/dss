pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import {TokenTypes} from "../TokenTypes.sol";

interface IProxyInitializer {
    function initialize(address tokenProxy, address masterMinter, TokenTypes.TokenInfo memory tokenInfo) external;
}
