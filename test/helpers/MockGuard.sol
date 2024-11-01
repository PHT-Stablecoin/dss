pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

contract MockGuard {
    mapping(address => mapping(address => mapping(bytes4 => bool))) acl;

    function canCall(address src, address dst, bytes4 sig) public view returns (bool) {
        return acl[src][dst][sig];
    }

    function permit(address src, address dst, bytes4 sig) public {
        acl[src][dst][sig] = true;
    }
}
