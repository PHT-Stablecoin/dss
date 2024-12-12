pragma solidity <=0.8.13;

import "forge-std/Script.sol";
import "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {DssProxyRegistry} from "dss-proxy/DssProxyRegistry.sol";

contract DssProxyDeployScript is Script, Test {
    using stdJson for string;

    DssProxyRegistry dssProxyRegistry;

    function chainId() internal view returns (uint256 _chainId) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            _chainId := chainid()
        }
    }
    function run() public {
        vm.startBroadcast();

        dssProxyRegistry = new DssProxyRegistry();
        address dssProxy = dssProxyRegistry.build(address(this));

        string memory root = vm.projectRoot();

        string memory path = string(
            abi.encodePacked(root, "/script/output/", vm.toString(chainId()), "/dssProxyDeploy.artifacts.json")
        );

        string memory artifacts = "artifacts";
        artifacts.serialize("dssProxyOwner", address(this));
        artifacts.serialize("dssProxy", address(dssProxy));
        string memory json = artifacts.serialize("dssProxyRegistry", address(dssProxyRegistry));
        json.write(path);

        vm.stopBroadcast();
    }
}
