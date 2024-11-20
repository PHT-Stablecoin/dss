pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/Script.sol";

import "dss-proxy/DssProxyRegistry.sol";

contract Version8Build is Script, Test {
    function run() public {
        console.log("Hello, world!");
        DssProxyRegistry registry = new DssProxyRegistry();
        console.log("registry", address(registry));
    }
}
