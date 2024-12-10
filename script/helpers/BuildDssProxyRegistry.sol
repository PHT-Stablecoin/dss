pragma solidity ^0.8.13;

import {DssProxyRegistry} from "dss-proxy/DssProxyRegistry.sol";

// this file exists in order for Foundry to build the DssProxyRegistry.sol
// this way, other code can use this build artificat to deploy the code
// eg. when the DssDeploy script which is < 0.8.0 needs to deploy
// DssProxyRegistry contract
contract BuildDssProxyRegistry {
    function build() private {
        DssProxyRegistry dssProxyRegistry = new DssProxyRegistry();
    }
}
