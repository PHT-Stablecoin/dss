pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import {GemJoin} from "dss/join.sol";
import {GemJoin2} from "dss-gem-joins/join-2.sol";
import {GemJoin3} from "dss-gem-joins/join-3.sol";
import {GemJoin4} from "dss-gem-joins/join-4.sol";
import {GemJoin5} from "dss-gem-joins/join-5.sol";

interface GemLike {
    function rely(address usr) external;
    function deny(address usr) external;
}

contract GemJoin1To5Fab {
    uint8 private constant GEM_JOIN_1 = 1;
    uint8 private constant GEM_JOIN_2 = 2;
    uint8 private constant GEM_JOIN_3 = 3;
    uint8 private constant GEM_JOIN_4 = 4;
    uint8 private constant GEM_JOIN_5 = 5;

    function createJoin(uint8 gemJoinIndex, address owner, address vat, bytes32 ilk, address token, uint8 tokenDecimals)
        external
        returns (address join)
    {
        require(gemJoinIndex != 0 && gemJoinIndex <= GEM_JOIN_5, "Invalid gemJoinIndex");

        if (gemJoinIndex == GEM_JOIN_3) {
            require(tokenDecimals != 0, "Invalid tokenDecimals");
        }

        join = gemJoinIndex == GEM_JOIN_1
            ? address(new GemJoin(vat, ilk, token))
            : gemJoinIndex == GEM_JOIN_2
                ? address(new GemJoin2(vat, ilk, token))
                : gemJoinIndex == GEM_JOIN_3
                    ? address(new GemJoin3(vat, ilk, token, tokenDecimals))
                    : gemJoinIndex == GEM_JOIN_4 ? address(new GemJoin4(vat, ilk, token)) : address(new GemJoin5(vat, ilk, token));

        GemLike(join).rely(owner);
        GemLike(join).deny(address(this));
    }
}
