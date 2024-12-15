pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

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
