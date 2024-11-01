pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import {DSToken} from "ds-token/token.sol";
import {DaiJoin} from "dss/join.sol";
import {ESM} from "./esm.sol";
import {FlipperLike, ClipperLike, HopeLike} from "./Interfaces.sol";
import {End} from "dss/end.sol";
import {Vat} from "dss/vat.sol";
import {GemJoin} from "dss/join.sol";
import {WETH} from "./WETH.sol";

contract FakeUser {
    function doApprove(address token, address guy) public {
        DSToken(token).approve(guy);
    }

    function doDaiJoin(address obj, address urn, uint wad) public {
        DaiJoin(obj).join(urn, wad);
    }

    function doDaiExit(address obj, address guy, uint wad) public {
        DaiJoin(obj).exit(guy, wad);
    }

    function doWethJoin(address obj, address gem, address urn, uint wad) public {
        WETH(obj).approve(address(gem), uint(-1));
        GemJoin(gem).join(urn, wad);
    }

    function doFrob(address obj, bytes32 ilk, address urn, address gem, address dai, int dink, int dart) public {
        Vat(obj).frob(ilk, urn, gem, dai, dink, dart);
    }

    function doFork(address obj, bytes32 ilk, address src, address dst, int dink, int dart) public {
        Vat(obj).fork(ilk, src, dst, dink, dart);
    }

    function doHope(address obj, address guy) public {
        HopeLike(obj).hope(guy);
    }

    function doTend(address obj, uint id, uint lot, uint bid) public {
        FlipperLike(obj).tend(id, lot, bid);
    }

    function doTake(address obj, uint256 id, uint256 amt, uint256 max, address who, bytes calldata data) external {
        ClipperLike(obj).take(id, amt, max, who, data);
    }

    function doDent(address obj, uint id, uint lot, uint bid) public {
        FlipperLike(obj).dent(id, lot, bid);
    }

    function doDeal(address obj, uint id) public {
        FlipperLike(obj).deal(id);
    }

    function doEndFree(address end, bytes32 ilk) public {
        End(end).free(ilk);
    }

    function doESMJoin(address gem, address esm, uint256 wad) public {
        DSToken(gem).approve(esm, uint256(-1));
        ESM(esm).join(wad);
    }
}
