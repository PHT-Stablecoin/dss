pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import {PHTCollateralHelper} from "./PHTCollateralHelper.sol";

struct PHTDeployConfig {
    string govTokenSymbol;
    uint256 dogHoleRad;
    uint256 vatLineRad;
    uint256 jugBase;
    address authorityOwner;
    address[] authorityRootUsers;
}
