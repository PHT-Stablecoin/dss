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

contract GemJoin1 {
    function createJoin(uint8 gemJoinIndex, address owner, address vat, bytes32 ilk, address token, uint8 tokenDecimals)
        external
        returns (address join)
    {
        require(gemJoinIndex != 0 && gemJoinIndex < 6, "Invalid gemJoinIndex");

        if (gemJoinIndex == 3) {
            require(tokenDecimals != 0, "Invalid tokenDecimals");
        }

        join = gemJoinIndex == 1
            ? address(new GemJoin(vat, ilk, token))
            : gemJoinIndex == 2
                ? address(new GemJoin2(vat, ilk, token))
                : gemJoinIndex == 3
                    ? address(new GemJoin3(vat, ilk, token, tokenDecimals))
                    : gemJoinIndex == 4 ? address(new GemJoin4(vat, ilk, token)) : address(new GemJoin5(vat, ilk, token));

        GemLike(join).rely(owner);
        GemLike(join).deny(address(this));
    }
}
