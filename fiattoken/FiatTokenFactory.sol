pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import {FiatTokenInfo} from "./TokenTypes.sol";
import {IImplementationDeployer} from "./interfaces/IImplementationDeployer.sol";
import {IMasterMinterDeployer} from "./interfaces/IMasterMinterDeployer.sol";
import {IProxyInitializer} from "./interfaces/IProxyInitializer.sol";
import {FiatTokenProxy} from "stablecoin-evm/v1/FiatTokenProxy.sol";

interface ITokenFactory {
    event TokenCreated(address implementation, address proxy, address creator);
    function create(
        FiatTokenInfo memory tokenInfo
    ) external returns (address implementation, address proxy, address masterMinter);
}

contract FiatTokenFactory is ITokenFactory {
    IImplementationDeployer public immutable IMPLEMENTATION_DEPLOYER;
    IMasterMinterDeployer public immutable MASTER_MINTER_DEPLOYER;
    IProxyInitializer public immutable PROXY_INITIALIZER;

    constructor(address _implementationDeployer, address _masterMinterDeployer, address _proxyInitializer) public {
        IMPLEMENTATION_DEPLOYER = IImplementationDeployer(_implementationDeployer);
        MASTER_MINTER_DEPLOYER = IMasterMinterDeployer(_masterMinterDeployer);
        PROXY_INITIALIZER = IProxyInitializer(_proxyInitializer);
    }

    function create(
        FiatTokenInfo memory tokenInfo
    ) external override returns (address implementation, address proxy, address masterMinter) {
        (implementation, proxy, masterMinter) = _deployAndInitialize(tokenInfo);
        emit TokenCreated(implementation, proxy, msg.sender);
        return (implementation, proxy, masterMinter);
    }

    function _deployAndInitialize(
        FiatTokenInfo memory tokenInfo
    ) internal returns (address implementation, address proxy, address masterMinter) {
        // Deploy the latest implementation contract code to the network.
        address implementation = IMPLEMENTATION_DEPLOYER.deployImplementation();

        // Deploy the proxy contract.
        FiatTokenProxy proxy = new FiatTokenProxy(implementation);

        // Now that the proxy contract has been deployed, we can deploy the master minter.
        if (tokenInfo.initialSupply > 0) {
            // temporarily give permissions to the factory to mint tokens
            masterMinter = MASTER_MINTER_DEPLOYER.deployMasterMinter(address(proxy), address(this));
        } else {
            masterMinter = MASTER_MINTER_DEPLOYER.deployMasterMinter(address(proxy), tokenInfo.masterMinterOwner);
        }

        // Now that the master minter is set up, we can go back to setting up the proxy and
        // implementation contracts.
        // Need to change admin first, or the call to initialize won't work
        // since admin can only call methods in the proxy, and not forwarded methods
        proxy.changeAdmin(tokenInfo.proxyAdmin);

        // Initialize the proxy contract.
        PROXY_INITIALIZER.initialize(address(proxy), masterMinter, tokenInfo);

        if (tokenInfo.initialSupply > 0) {
            // temporarily give permissions to the factory to mint tokens
            IMasterMinter(masterMinter).configureController(address(this), address(this));
            IMasterMinter(masterMinter).configureMinter(tokenInfo.initialSupply);
            IFiatToken(address(proxy)).mint(tokenInfo.initialSupplyMintTo, tokenInfo.initialSupply);
            // remove permissions
            IMasterMinter(masterMinter).removeMinter();
            IMasterMinter(masterMinter).removeController(address(this));
            // undo MASTER_MINTER_DEPLOYER.deployMasterMinter permissions
            // Configure controller (adds owner as minter)
            IMasterMinter(masterMinter).configureController(tokenInfo.masterMinterOwner, tokenInfo.masterMinterOwner);
            // Transfer ownership to owner after configuring (this contract loses control)
            IMasterMinter(masterMinter).transferOwnership(tokenInfo.masterMinterOwner);
        }

        return (implementation, address(proxy), masterMinter);
    }
}

interface IFiatToken {
    function mint(address _to, uint256 _amount) external returns (bool);
}

interface IMasterMinter {
    function configureController(address controller, address worker) external;
    function configureMinter(uint256 minterAllowedAmount) external returns (bool);
    function removeController(address controller) external;
    function removeMinter() external returns (bool);
    function transferOwnership(address newOwner) external;
}
