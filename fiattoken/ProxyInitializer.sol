pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import {FiatTokenV2_2} from "stablecoin-evm/v2/FiatTokenV2_2.sol";
// import {FiatTokenInfo} from "./TokenTypes.sol";
// import {IProxyInitializer} from "./interfaces/IProxyInitializer.sol";

struct FiatTokenInfo {
    string tokenName;
    string tokenSymbol;
    uint8 tokenDecimals;
    string tokenCurrency;
    uint256 initialSupply;
    address initialSupplyMintTo; // address to mint the initial supply to
    address masterMinterOwner;
    address proxyAdmin;
    address pauser;
    address blacklister;
    address owner;
}

interface IProxyInitializer {
    function initialize(address tokenProxy, address masterMinter, FiatTokenInfo memory tokenInfo) external;
}

contract ProxyInitializer is IProxyInitializer {
    function initialize(address proxy, address masterMinter, FiatTokenInfo memory tokenInfo) external override {
        // Do the initial (V1) initialization.
        // Note that this takes in the master minter contract's address as the master minter.
        // The master minter contract's owner is a separate address.
        FiatTokenV2_2 proxyAsV2_2 = FiatTokenV2_2(proxy);
        proxyAsV2_2.initialize(
            tokenInfo.tokenName,
            tokenInfo.tokenSymbol,
            tokenInfo.tokenCurrency,
            tokenInfo.tokenDecimals,
            masterMinter,
            tokenInfo.pauser,
            tokenInfo.blacklister,
            tokenInfo.owner
        );

        // Do the V2 initialization
        proxyAsV2_2.initializeV2(tokenInfo.tokenName);

        // Do the V2_1 initialization
        proxyAsV2_2.initializeV2_1(tokenInfo.owner);

        // Do the V2_2 initialization
        proxyAsV2_2.initializeV2_2(new address[](0), tokenInfo.tokenSymbol);
    }
}
