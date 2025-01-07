pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import {DSToken} from "ds-token/token.sol";

// Collateral Token (USDT)
contract TestUSDT is DSToken {
    constructor() public DSToken("tstUSDT") {
        decimals = 6;
        name = "Test USDT";
    }
}
