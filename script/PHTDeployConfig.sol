pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

struct PHTDeployConfig {
    string govTokenSymbol;
    address phtUsdFeed; // optional for testing environments
    uint256 dogHoleRad;
    uint256 vatLineRad;
    uint256 jugBase;
    address authorityOwner;
    address[] authorityRootUsers;
}
