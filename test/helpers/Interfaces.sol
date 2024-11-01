pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

interface FlipperLike {
    function tend(uint, uint, uint) external;
    function dent(uint, uint, uint) external;
    function deal(uint) external;
}

interface ClipperLike {
    function take(uint, uint, uint, address, bytes calldata) external;
}

interface HopeLike {
    function hope(address guy) external;
}
