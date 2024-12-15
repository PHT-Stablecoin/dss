pragma solidity ^0.6.12;

import {MasterMinter} from "stablecoin-evm/minting/MasterMinter.sol";
import {IMasterMinterDeployer} from "./interfaces/IMasterMinterDeployer.sol";

contract MasterMinterDeployer is IMasterMinterDeployer {
    function deployMasterMinter(address token, address owner) external override returns (address) {
        MasterMinter masterMinter = new MasterMinter(token);

        // Configure controller (adds owner as minter)
        masterMinter.configureController(owner, owner);

        // Transfer ownership to owner after configuring (this contract loses control)
        masterMinter.transferOwnership(owner);

        return address(masterMinter);
    }
}
