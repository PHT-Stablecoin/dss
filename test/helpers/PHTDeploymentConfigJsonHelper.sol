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
        uint256 vowBumpRad;
        uint256 vowDumpWad;
        uint256 vowHumpRad;
        uint256 vowSumpRad;
        uint256 vowWaitSeconds;
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
        uint64 chip;
        uint256 chop;
        uint256 cusp;
        uint256 dust;
        uint256 duty;
        uint256 holeRad;
        bytes32 ilk;
        uint256 lineRad;
        uint256 matEther;
        uint256 tail;
        uint256 tau;
        uint192 tip;
    }

    struct TokenParams {
        string currency;
        uint8 decimals;
        uint256 initialSupply;
        address initialSupplyMintTo;
        uint256 maxSupply;
        string name;
        string symbol;
        address token;
        address tokenAdmin;
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
