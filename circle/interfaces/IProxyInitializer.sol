pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import {FiatTokenInfo} from "../TokenTypes.sol";

interface IProxyInitializer {
    function initialize(address tokenProxy, address masterMinter, FiatTokenInfo memory tokenInfo) external;
}
