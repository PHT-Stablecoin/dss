pragma solidity ^0.6.12;

interface IMasterMinterDeployer {
    function deployMasterMinter(address token, address owner) external returns (address);
}
