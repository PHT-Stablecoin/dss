// SPDX-License-Identifier: AGPL-3.0-or-later

/// spot.sol -- Spotter

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity ^0.6.12;

import {console} from "forge-std/console.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

// FIXME: This contract was altered compared to the production version.
// It doesn't use LibNote anymore.
// New deployments of this contract will need to include custom events (TO DO).

interface VatLike {
    function file(bytes32, bytes32, uint) external;
}

interface PipLike {
    function peek() external returns (bytes32, bool);
}

contract ChainlinkSpotter {
    // --- Auth ---
    mapping(address => uint) public wards;
    function rely(address guy) external auth {
        wards[guy] = 1;
    }
    function deny(address guy) external auth {
        wards[guy] = 0;
    }
    modifier auth() {
        require(wards[msg.sender] == 1, "ChainlinkSpotter/not-authorized");
        _;
    }

    // --- Data ---
    struct Ilk {
        AggregatorV3Interface pip; // Chainlink Price Feed
        uint256 mat; // Liquidation ratio [ray]
    }

    mapping(bytes32 => Ilk) public ilks;

    VatLike public vat; // CDP Engine
    uint256 public par; // ref per dai [ray]

    uint256 public live;

    // --- Events ---
    event Poke(
        bytes32 ilk,
        bytes32 val, // [wad]
        uint256 spot // [ray]
    );

    // --- Init ---
    constructor(address vat_) public {
        wards[msg.sender] = 1;
        vat = VatLike(vat_);
        par = ONE;
        live = 1;
    }

    // --- Math ---
    uint constant ONE = 10 ** 27;

    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x);
    }
    function rdiv(uint x, uint y) internal pure returns (uint z) {
        z = mul(x, ONE) / y;
    }

    // --- Administration ---
    function file(bytes32 ilk, bytes32 what, address pip_) external auth {
        require(live == 1, "ChainlinkSpotter/not-live");
        if (what == "pip") ilks[ilk].pip = AggregatorV3Interface(pip_);
        else revert("ChainlinkSpotter/file-unrecognized-param");
    }
    function file(bytes32 what, uint data) external auth {
        require(live == 1, "ChainlinkSpotter/not-live");
        if (what == "par") par = data;
        else revert("ChainlinkSpotter/file-unrecognized-param");
    }
    function file(bytes32 ilk, bytes32 what, uint data) external auth {
        require(live == 1, "ChainlinkSpotter/not-live");
        if (what == "mat") ilks[ilk].mat = data;
        else revert("ChainlinkSpotter/file-unrecognized-param");
    }

    // --- Update value ---
    function poke(bytes32 ilk) external {
        console.log("ChainlinkSpotter.poke 0", string(abi.encodePacked(ilk)));
        (
            uint80 roundId,
            int256 answer,
            // uint256 startedAt,
            // uint256 updatedAt,
            // uint80 answeredInRound
        ) = ilks[ilk].pip.latestRoundData();

        console.log("ChainlinkSpotter.poke answer", answer);
        console.log("ChainlinkSpotter.poke roundId", roundId);
        console.log("ilks[ilk].mat", ilks[ilk].mat);
        uint256 spot = roundId > 0 ? rdiv(rdiv(mul(uint(answer), 10 ** 9), par), ilks[ilk].mat) : 0;
        vat.file(ilk, "spot", spot);
        emit Poke(ilk, val, spot);
    }

    function cage() external auth {
        live = 0;
    }
}
