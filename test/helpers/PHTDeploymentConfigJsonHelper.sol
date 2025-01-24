// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import {CommonBase} from "forge-std/Base.sol";

interface IPHTDeployConfigJson {
    struct Root {
        string _notes;
        address authorityOwner;
        address[] authorityRootUsers;
        Collateral[] collaterals;
        uint256 dogHoleRad;
        string govTokenSymbol;
        uint256 jugBase;
        // for prod specify the chainlink PHP/USD feed; for testing specify address(0)
        address phtUsdFeed;
        uint256 vatLineRad;
    }

    struct Collateral {
        FeedParams feedParams;
        IlkParams ilkParams;
        TokenParams tokenParams;
    }

    struct FeedParams {
        uint8 decimals;
        address denominatorFeed;
        address feed;
        string feedDescription;
        int256 initialPrice;
        bool invertDenominator;
        bool invertNumerator;
        address numeratorFeed;
    }

    struct IlkParams {
        uint256 buf;
        uint256 chop;
        uint256 dust;
        uint256 duty;
        uint256 holeRad;
        bytes32 ilk;
        uint256 lineRad;
        uint256 matEther;
        uint256 tau;
        uint256 cusp;
        uint256 chip;
        uint256 tip;
        uint256 tail;
    }

    struct TokenParams {
        uint8 decimals;
        uint256 initialSupply;
        uint256 maxSupply;
        string name;
        string symbol;
        address token;
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
