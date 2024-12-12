pragma solidity ^0.8.13;
pragma experimental ABIEncoderV2;

import "forge-std/Test.sol";
import "dss-proxy/DssProxyRegistry.sol";

contract Version8BuildTest is Test {
    function testVersion8Build() public {
        console.log("Hello, world!");
        DssProxyRegistry registry = new DssProxyRegistry();
        console.log("registry", address(registry));
    }
}
