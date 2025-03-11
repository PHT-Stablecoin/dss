pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "forge-std/Script.sol";
import "forge-std/Test.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {ProxyInitializer} from "../fiattoken/ProxyInitializer.sol";
// import {MasterMinterDeployer} from "../fiattoken/MasterMinterDeployer.sol";

contract FixFiatTokenFactoryPHTCollateralHelper is Script, Test {
    function run() public {
        vm.startBroadcast();

        ProxyInitializer proxyInitializer = new ProxyInitializer();
        console.log("proxyInitializer", address(proxyInitializer));

        vm.stopBroadcast();
    }
}
