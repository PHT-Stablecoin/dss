pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import {FiatTokenInfo} from "./TokenTypes.sol";
import {IImplementationDeployer} from "./interfaces/IImplementationDeployer.sol";
import {IMasterMinterDeployer} from "./interfaces/IMasterMinterDeployer.sol";
import {IProxyInitializer} from "./interfaces/IProxyInitializer.sol";
import {FiatTokenProxy} from "stablecoin-evm/v1/FiatTokenProxy.sol";

interface ITokenFactory {
    event TokenCreated(address implementation, address proxy, address creator);

    function create(FiatTokenInfo memory tokenInfo)
        external
        returns (address implementation, address proxy, address masterMinter);
}

struct FactoryToken {
    address implementation;
    address masterMinter;
}

contract FiatTokenFactory is ITokenFactory {
    IImplementationDeployer public immutable IMPLEMENTATION_DEPLOYER;
    IMasterMinterDeployer public immutable MASTER_MINTER_DEPLOYER;
    IProxyInitializer public immutable PROXY_INITIALIZER;

    // --- Auth ---
    mapping(address => uint256) public wards;

    function rely(address usr) external auth {
        wards[usr] = 1;
    }

    function deny(address usr) external auth {
        wards[usr] = 0;
    }

    modifier auth() {
        require(wards[msg.sender] == 1, "FiatTokenFactory/not-authorized");
        _;
    }

    // proxy address => FactoryToken
    mapping(address => FactoryToken) public tokens;
    // list of all proxy token addresses
    address[] public tokenAddresses;

    constructor(address _implementationDeployer, address _masterMinterDeployer, address _proxyInitializer) public {
        require(_implementationDeployer != address(0), "FiatTokenFactory/implementation-deployer-not-set");
        require(_masterMinterDeployer != address(0), "FiatTokenFactory/master-minter-deployer-not-set");
        require(_proxyInitializer != address(0), "FiatTokenFactory/proxy-initializer-not-set");

        IMPLEMENTATION_DEPLOYER = IImplementationDeployer(_implementationDeployer);
        MASTER_MINTER_DEPLOYER = IMasterMinterDeployer(_masterMinterDeployer);
        PROXY_INITIALIZER = IProxyInitializer(_proxyInitializer);
        wards[msg.sender] = 1;
    }

    function create(FiatTokenInfo memory tokenInfo)
        external
        override
        auth
        returns (address implementation, address proxy, address masterMinter)
    {
        (implementation, proxy, masterMinter) = _deployAndInitialize(tokenInfo);
        tokenAddresses.push(proxy);
        tokens[proxy] = FactoryToken({implementation: implementation, masterMinter: masterMinter});

        emit TokenCreated(implementation, proxy, msg.sender);

        return (implementation, proxy, masterMinter);
    }

    function lastToken() public view returns (uint256) {
        return tokenAddresses.length - 1;
    }

    function _deployAndInitialize(FiatTokenInfo memory tokenInfo)
        internal
        returns (address implementation, address proxy, address masterMinter)
    {
        // Deploy the latest implementation contract code to the network.
        address implementation = IMPLEMENTATION_DEPLOYER.deployImplementation();

        // Deploy the proxy contract.
        FiatTokenProxy proxy = new FiatTokenProxy(implementation);

        // Now that the proxy contract has been deployed, we can deploy the master minter.
        masterMinter = MASTER_MINTER_DEPLOYER.deployMasterMinter(address(proxy), address(this));

        // Now that the master minter is set up, we can go back to setting up the proxy and
        // implementation contracts.
        // Need to change admin first, or the call to initialize won't work
        // since admin can only call methods in the proxy, and not forwarded methods
        proxy.changeAdmin(tokenInfo.proxyAdmin);

        FiatTokenInfo memory copy = tokenInfo;
        copy.owner = address(this);

        // Initialize the proxy contract.
        PROXY_INITIALIZER.initialize(address(proxy), masterMinter, copy);

        IMasterMinter(masterMinter).configureController(address(this), address(this));

        if (tokenInfo.initialSupply > 0) {
            // temporarily give permissions to the factory to mint tokens
            require(
                IMasterMinter(masterMinter).configureMinter(tokenInfo.initialSupply), "FiatTokenFactory/configureMinter"
            );
            require(
                IFiatToken(address(proxy)).mint(tokenInfo.initialSupplyMintTo, tokenInfo.initialSupply),
                "FiatTokenFactory/mint"
            );
            // remove permissions
            require(IMasterMinter(masterMinter).removeMinter(), "FiatTokenFactory/removeMinter");
        }
        // Configure controller (adds owner as minter)
        IFiatToken(address(proxy)).updateMasterMinter(address(this));
        IFiatToken(address(proxy)).configureMinter(tokenInfo.masterMinterOwner, uint256(-1));
        IMasterMinter(masterMinter).removeController(address(this));
        IMasterMinter(masterMinter).transferOwnership(tokenInfo.masterMinterOwner);
        IFiatToken(address(proxy)).updateMasterMinter(tokenInfo.masterMinterOwner);
        // Transfer ownership to owner after configuring (this contract loses control)
        IFiatToken(address(proxy)).transferOwnership(tokenInfo.owner);

        return (implementation, address(proxy), masterMinter);
    }
}

interface IFiatToken {
    function owner() external returns (address);
    function mint(address _to, uint256 _amount) external returns (bool);
    function configureMinter(address minter, uint256 minterAllowedAmount) external returns (bool);
    function transferOwnership(address newOwner) external;
    function updateMasterMinter(address _newMasterMinter) external;
}

interface IMasterMinter {
    function configureController(address controller, address worker) external;
    function configureMinter(uint256 minterAllowedAmount) external returns (bool);
    function removeController(address controller) external;
    function removeMinter() external returns (bool);
    function transferOwnership(address newOwner) external;
}
