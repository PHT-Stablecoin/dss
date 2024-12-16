// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import {CommonBase} from "forge-std/Base.sol";

interface IPHTDeployConfigJson {
    struct Root {
        address authorityOwner;
        address[] authorityRootUsers;
        uint256 dogHoleRad;
        string govTokenSymbol;
        uint256 jugBase;
        // for prod specify the chainlink PHP/USD feed; for testing specify address(0)
        address phtUsdFeed;
        uint256 vatLineRad;
    }
}

contract PHTDeploymentConfigJsonHelper is CommonBase {
    function readDeploymentConfig(string memory jsonFileName) public view returns (IPHTDeployConfigJson.Root memory) {
        string memory path = string(abi.encodePacked(vm.projectRoot(), "/config/", jsonFileName));
        string memory json = vm.readFile(path);
        bytes memory data = vm.parseJson(json);
        IPHTDeployConfigJson.Root memory root = abi.decode(data, (IPHTDeployConfigJson.Root));

        return root;
    }
}
