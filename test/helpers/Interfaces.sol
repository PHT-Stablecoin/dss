pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

interface FlipperLike {
    function tend(uint256, uint256, uint256) external;
    function dent(uint256, uint256, uint256) external;
    function deal(uint256) external;
}

interface ClipperLike {
    function take(uint256, uint256, uint256, address, bytes calldata) external;
}

interface HopeLike {
    function hope(address guy) external;
}
