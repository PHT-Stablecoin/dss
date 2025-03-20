pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import {GemJoin6} from "dss-gem-joins/join-6.sol";
import {GemJoin7} from "dss-gem-joins/join-7.sol";
import {GemJoin8} from "dss-gem-joins/join-8.sol";
import {GemJoin9} from "dss-gem-joins/join-9.sol";
import {AuthGemJoin} from "dss-gem-joins/join-auth.sol";
import {ManagedGemJoin} from "dss-gem-joins/join-managed.sol";

interface GemLike {
    function rely(address usr) external;
    function deny(address usr) external;
}

contract GemJoin2 {
    function createJoin(uint8 gemJoinIndex, address owner, address vat, bytes32 ilk, address token)
        external
        returns (address join)
    {
        require(gemJoinIndex > 5 && gemJoinIndex < 12, "Invalid gemJoinIndex");

        join = gemJoinIndex == 6
            ? address(new GemJoin6(vat, ilk, token))
            : gemJoinIndex == 7
                ? address(new GemJoin7(vat, ilk, token))
                : gemJoinIndex == 8
                    ? address(new GemJoin8(vat, ilk, token))
                    : gemJoinIndex == 9
                        ? address(new GemJoin9(vat, ilk, token))
                        : gemJoinIndex == 10 ? address(new AuthGemJoin(vat, ilk, token)) : address(new ManagedGemJoin(vat, ilk, token));

        GemLike(join).rely(owner);
        GemLike(join).deny(address(this));
    }
}
