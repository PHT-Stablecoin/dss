pragma solidity ^0.6.12;

import {FiatTokenV2_2} from "stablecoin-evm/v2/FiatTokenV2_2.sol";
import {IImplementationDeployer} from "./interfaces/IImplementationDeployer.sol";

contract ImplementationDeployer is IImplementationDeployer {
    address private constant _THROWAWAY_ADDRESS = address(1);

    function deployImplementation() external override returns (address) {
        FiatTokenV2_2 implementation = new FiatTokenV2_2();

        // Initializing the implementation contract with dummy values here prevents
        // the contract from being reinitialized later on with different values.
        // Dummy values can be used here as the proxy contract will store the actual values
        // for the deployed token.
        implementation.initialize(
            "",
            "",
            "",
            0,
            _THROWAWAY_ADDRESS,
            _THROWAWAY_ADDRESS,
            _THROWAWAY_ADDRESS,
            _THROWAWAY_ADDRESS
        );
        implementation.initializeV2("");
        implementation.initializeV2_1(_THROWAWAY_ADDRESS);
        implementation.initializeV2_2(new address[](0), "");

        return address(implementation);
    }
}
