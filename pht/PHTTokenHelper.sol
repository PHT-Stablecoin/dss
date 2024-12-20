pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import {DSAuth, DSAuthority} from "ds-auth/auth.sol";
import {DSPause} from "ds-pause/pause.sol";

import {FactoryToken, FiatTokenFactory, IMasterMinter} from "../fiattoken/FiatTokenFactory.sol";
import {FiatTokenInfo} from "../fiattoken/TokenTypes.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IFiatToken is IERC20 {
    function mint(address _to, uint256 _amount) external returns (bool);
    function blacklist(address _account) external;
    function unBlacklist(address _account) external;
    function isBlacklisted(address _account) external view returns (bool);
}

contract PHTTokenHelper is DSAuth {

    struct TokenInfo {
        string tokenName;
        string tokenSymbol;
        uint8 tokenDecimals;
        string tokenCurrency;
        uint256 initialSupply;
        address initialSupplyMintTo; // address to mint the initial supply to
    }

    FiatTokenFactory public tokenFactory;
    DSPause public pause;

    constructor(DSPause pause_, FiatTokenFactory tokenFactory_) public {
        tokenFactory = tokenFactory_;
        pause  = pause_;
        authority = DSAuthority(pause.authority());
    }

    function tokenAddresses(uint256 index) view public returns (address) {
        return tokenFactory.tokenAddresses(index);
    }

    function tokens(address token) view public returns (FactoryToken memory t) {
        (t.implementation, t.masterMinter) = tokenFactory.tokens(token);
    }

    function lastToken() view public returns (uint256) {
        return tokenFactory.lastToken();
    }

    function createToken(TokenInfo memory info) auth public returns (address implementation, address proxy, address masterMinter) {

        (implementation, proxy, masterMinter) = tokenFactory.create(FiatTokenInfo({
                tokenName: info.tokenName,
                tokenSymbol: info.tokenSymbol,
                tokenDecimals: info.tokenDecimals,
                tokenCurrency: info.tokenCurrency,
                initialSupply: info.initialSupply,
                initialSupplyMintTo: info.initialSupplyMintTo, // address to mint the initial supply to
                masterMinterOwner: address(this),
                proxyAdmin: address(pause.proxy()),
                pauser: address(this),
                blacklister: address(this),
                owner: address(this)
        }));

        IMasterMinter(masterMinter).configureMinter(uint(-1));
        IMasterMinter(masterMinter).configureController(address(this), address(this));
    }

    function configureMinter(address masterMinter) auth public {
        IMasterMinter(masterMinter).configureMinter(uint(-1));
        IMasterMinter(masterMinter).configureController(address(this), address(this));
    }

    function mint(address token, address to, uint256 val) auth public returns (bool) {
        return IFiatToken(token).mint(to, val);
    }

    function blacklist(address token, address target) auth public {
        return IFiatToken(token).blacklist(target);
    }

    function unBlacklist(address token, address target) auth public {
        return IFiatToken(token).unBlacklist(target);
    }

}