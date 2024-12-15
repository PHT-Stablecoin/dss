pragma solidity ^0.6.12;

interface IImplementationDeployer {
    function deployImplementation() external returns (address);
}
