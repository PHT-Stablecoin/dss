pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import {DSAuth, DSAuthority} from "ds-auth/auth.sol";
import {DSPause} from "ds-pause/pause.sol";

import {FactoryToken, FiatTokenFactory, IMasterMinter} from "../fiattoken/FiatTokenFactory.sol";
import {FiatTokenInfo} from "../fiattoken/TokenTypes.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {FiatTokenV1} from "stablecoin-evm/v1/FiatTokenV1.sol";

interface IFiatToken is IERC20 {
    function mint(address _to, uint256 _amount) external;
    function blacklist(address _account) external;
    function unBlacklist(address _account) external;
    function isBlacklisted(address _account) external view returns (bool);
}

struct DelayedAction {
    address usr;
    bytes32 tag;
    uint256 eta;
    bytes fax;
}

struct TokenInfo {
    string tokenName;
    string tokenSymbol;
    uint8 tokenDecimals;
    string tokenCurrency;
    uint256 initialSupply;
    address initialSupplyMintTo; // address to mint the initial supply to
    address tokenAdmin; // address to give token admin rights
}

contract TokenActions {
    function mint(address token, address to, uint256 val) public returns (bool) {
        IFiatToken(token).mint(to, val);
        return true;
    }

    function blacklist(address token, address target) public {
        return IFiatToken(token).blacklist(target);
    }

    function unBlacklist(address token, address target) public {
        return IFiatToken(token).unBlacklist(target);
    }
}

contract PHTTokenHelper is DSAuth {
    DSPause public pause;
    TokenActions public tokenActions;

    FiatTokenFactory public tokenFactory;

    constructor(DSPause pause_, TokenActions tokenActions_, FiatTokenFactory tokenFactory_) public {
        require(address(tokenFactory_) != address(0), "PHTTokenHelper/token-factory-not-set");
        require(address(pause_) != address(0), "PHTTokenHelper/pause-not-set");

        tokenFactory = tokenFactory_;
        tokenActions = TokenActions(tokenActions_);
        pause = pause_;
        authority = DSAuthority(pause.authority());
    }

    function tokenAddresses(uint256 index) public view returns (address) {
        return tokenFactory.tokenAddresses(index);
    }

    function tokens(address token) public view returns (FactoryToken memory t) {
        (t.implementation, t.masterMinter) = tokenFactory.tokens(token);
    }

    function lastToken() public view returns (uint256) {
        return tokenFactory.lastToken();
    }

    function createToken(TokenInfo memory info)
        public
        auth
        returns (address implementation, address proxy, address masterMinter)
    {
        address pauseProxy = address(pause.proxy());
        (implementation, proxy, masterMinter) = tokenFactory.create(
            FiatTokenInfo({
                tokenName: info.tokenName,
                tokenSymbol: info.tokenSymbol,
                tokenDecimals: info.tokenDecimals,
                tokenCurrency: info.tokenCurrency,
                initialSupply: info.initialSupply,
                initialSupplyMintTo: info.initialSupplyMintTo, // address to mint the initial supply to
                masterMinterOwner: pauseProxy, // this is proxy
                proxyAdmin: info.tokenAdmin,
                pauser: pauseProxy,
                blacklister: pauseProxy,
                owner: pauseProxy
            })
        );
    }

    function mint(address token, address to, uint256 val) public auth returns (DelayedAction memory a, bool c) {
        address usr = address(tokenActions);
        bytes32 tag;
        assembly {
            tag := extcodehash(usr)
        }
        bytes memory fax = abi.encodeWithSelector(tokenActions.mint.selector, token, to, val);
        uint256 delay = pause.delay();
        uint256 eta = now + delay;

        pause.plot(usr, tag, fax, eta);
        if (delay == 0) {
            c = abi.decode(pause.exec(usr, tag, fax, eta), (bool));
        }
        a = DelayedAction(usr, tag, eta, fax);
    }

    function blacklist(address token, address target) public auth returns (DelayedAction memory a) {
        address usr = address(tokenActions);
        bytes32 tag;
        assembly {
            tag := extcodehash(usr)
        }
        bytes memory fax = abi.encodeWithSelector(tokenActions.blacklist.selector, token, target);
        uint256 delay = pause.delay();
        uint256 eta = now + delay;

        pause.plot(usr, tag, fax, eta);
        if (delay == 0) pause.exec(usr, tag, fax, eta);
        a = DelayedAction(usr, tag, eta, fax);
    }

    function unBlacklist(address token, address target) public auth returns (DelayedAction memory a) {
        address usr = address(tokenActions);
        bytes32 tag;
        assembly {
            tag := extcodehash(usr)
        }
        bytes memory fax = abi.encodeWithSelector(tokenActions.unBlacklist.selector, token, target);
        uint256 delay = pause.delay();
        uint256 eta = now + delay;

        pause.plot(usr, tag, fax, eta);
        if (delay == 0) pause.exec(usr, tag, fax, eta);
        a = DelayedAction(usr, tag, eta, fax);
    }
}
