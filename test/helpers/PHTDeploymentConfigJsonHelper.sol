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
        string govTokenName;
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

        // sanity checks
        require(bytes(root.govTokenName).length > 0, "PHTDeploymentConfigJsonHelper/govTokenName is required");
        require(bytes(root.govTokenSymbol).length > 0, "PHTDeploymentConfigJsonHelper/govTokenSymbol is required");
        require(root.authorityOwner != address(0), "PHTDeploymentConfigJsonHelper/authorityOwner is required");
        require(root.authorityRootUsers.length > 0, "PHTDeploymentConfigJsonHelper/authorityRootUsers is required");
        require(root.dogHoleRad > 0, "PHTDeploymentConfigJsonHelper/dogHoleRad is required");
        require(root.vatLineRad > 0, "PHTDeploymentConfigJsonHelper/vatLineRad is required");
        require(root.jugBase > 0, "PHTDeploymentConfigJsonHelper/jugBase is required");
        require(root.vowBumpRad > 0, "PHTDeploymentConfigJsonHelper/vowBumpRad is required");
        require(root.vowDumpWad > 0, "PHTDeploymentConfigJsonHelper/vowDumpWad is required");
        require(root.vowHumpRad > 0, "PHTDeploymentConfigJsonHelper/vowHumpRad is required");
        require(root.vowSumpRad > 0, "PHTDeploymentConfigJsonHelper/vowSumpRad is required");
        require(root.vowWaitSeconds > 0, "PHTDeploymentConfigJsonHelper/vowWaitSeconds is required");

        return root;
    }
}
