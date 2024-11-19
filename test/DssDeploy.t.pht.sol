// SPDX-License-Identifier: AGPL-3.0-or-later
//
// DssDeploy.t.sol
//
// Copyright (C) 2018-2022 Dai Foundation
//
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
pragma experimental ABIEncoderV2;

import "./DssDeploy.t.base.pht.sol";

contract DssDeployTestPHT is DssDeployTestBasePHT {

    function testAuth() public {
        deployKeepAuth(address(dssDeploy));
        checkAuth();

        // Release Auth
        dssDeploy.releaseAuth(address(dssDeploy));
        dssDeploy.releaseAuthClip("PHP-A", address(dssDeploy));
        dssDeploy.releaseAuthClip("USDT-A", address(dssDeploy));
        checkReleasedAuth();
    }

    /**
     * Test: liquidate Vault by paying PHT and receiving the collateral (PHP)
     * - Min collateral ratio 105%
     * - simulate price drop to make collateral ratio of Vault to 103%
     * - show where the surplus 3% is going (Vow contract)
    **/
    function testLiquidation() public {
        deployKeepAuth(address(dssDeploy));

        php.mint(2 ether);
        assertEq(php.balanceOf(address(this)), 2 ether);
        assertEq(vat.gem("PHP-A", address(this)), 0);

        php.approve(address(phpJoin), 2 ether);
        phpJoin.join(address(this), 2 ether);
        assertEq(php.balanceOf(address(this)), 0);
        assertEq(vat.gem("PHP-A", address(this)), 2 ether);
        
        // Set Min Liquidiation Ratio = 105%
        proxyActions.file(address(spotter), "PHP-A", "mat", uint(1050000000 ether));
        spotter.poke("PHP-A");

        // Borrow at 105%
        vat.frob("PHP-A", address(this), address(this), address(this), 1.2 ether, 1 ether);
        assertEq(vat.gem("PHP-A", address(this)), 0.8 ether);
        assertEq(vat.dai(address(this)), mul(RAY, 1 ether));

        // Simulate Price Drop of ()
        feedPHP.file("answer", int(0.5 * 10 ** 6)); // Price 1 DAI (PHT) = 0.5 PHP (precision 6)
        spotter.poke("PHP-A");

        // Trigger Liquidation
        uint256 auctionid = dog.bark("PHP-A", address(this), address(this));
        assertNotEq(vat.gem("PHP-A", address(this)), 0.8 ether);

        // TODO: show amount liquidated
    }



    function checkAuth() internal {
        // vat
        assertEq(vat.wards(address(dssDeploy)), 1, "dssDeploy wards");
        assertEq(vat.wards(address(phpJoin)), 1, "phpJoin wards");
        assertEq(vat.wards(address(usdtJoin)), 1, "usdtJoin wards");
        assertEq(vat.wards(address(cat)), 1, "cat wards");
        assertEq(vat.wards(address(dog)), 1, "dog wards");
        assertEq(vat.wards(address(usdtClip)), 1, "usdtClip wards");
        assertEq(vat.wards(address(jug)), 1, "jug wards");
        assertEq(vat.wards(address(spotter)), 1, "spotter wards");
        assertEq(vat.wards(address(end)), 1, "end wards");
        assertEq(vat.wards(address(esm)), 1, "esm wards");
        assertEq(vat.wards(address(dssDeploy.pause().proxy())), 1, "pause proxy wards");

        // cat
        assertEq(cat.wards(address(dssDeploy)), 1, "dssDeploy wards");
        assertEq(cat.wards(address(end)), 1, "end wards");
        assertEq(cat.wards(address(dssDeploy.pause().proxy())), 1, "pause proxy wards");

        // dog
        assertEq(dog.wards(address(dssDeploy)), 1, "dssDeploy wards");
        assertEq(dog.wards(address(end)), 1, "dssDeploy end wards");
        assertEq(dog.wards(address(dssDeploy.pause().proxy())), 1, "pause proxy wards");

        // vow
        assertEq(vow.wards(address(dssDeploy)), 1);
        assertEq(vow.wards(address(cat)), 1, "cat wards");
        assertEq(vow.wards(address(end)), 1, "end wards");
        assertEq(vow.wards(address(dssDeploy.pause().proxy())), 1, "pause proxy wards");

        // jug
        assertEq(jug.wards(address(dssDeploy)), 1, "jug.dssDeploy wards");
        assertEq(jug.wards(address(dssDeploy.pause().proxy())), 1, "jug.pause proxy wards");

        // pot
        assertEq(pot.wards(address(dssDeploy)), 1, "pot.dssDeploy wards");
        assertEq(pot.wards(address(dssDeploy.pause().proxy())), 1, "pot.pause proxy wards");

        // dai
        assertEq(dai.wards(address(dssDeploy)), 1, "dai.dssDeploy wards");

        // spotter
        assertEq(spotter.wards(address(dssDeploy)), 1, "spotter.dssDeploy wards");
        assertEq(spotter.wards(address(dssDeploy.pause().proxy())), 1, "spotter.pause proxy wards");

        // flap
        assertEq(flap.wards(address(dssDeploy)), 1);
        assertEq(flap.wards(address(vow)), 1);
        assertEq(flap.wards(address(dssDeploy.pause().proxy())), 1);

        // flop
        assertEq(flop.wards(address(dssDeploy)), 1);
        assertEq(flop.wards(address(vow)), 1);
        assertEq(flop.wards(address(dssDeploy.pause().proxy())), 1);

        // cure
        assertEq(cure.wards(address(dssDeploy)), 1);
        assertEq(cure.wards(address(end)), 1);
        assertEq(cure.wards(address(dssDeploy.pause().proxy())), 1);

        // end
        assertEq(end.wards(address(dssDeploy)), 1);
        assertEq(end.wards(address(esm)), 1);
        assertEq(end.wards(address(dssDeploy.pause().proxy())), 1);

        // clips
        assertEq(phpClip.wards(address(dssDeploy)), 1);
        assertEq(phpClip.wards(address(end)), 1);
        assertEq(phpClip.wards(address(dssDeploy.pause().proxy())), 1);
        assertEq(phpClip.wards(address(esm)), 1);

        assertEq(usdtClip.wards(address(dssDeploy)), 1);
        assertEq(usdtClip.wards(address(end)), 1);
        assertEq(usdtClip.wards(address(dssDeploy.pause().proxy())), 1);
        assertEq(usdtClip.wards(address(esm)), 1);

        // pause
        assertEq(address(dssDeploy.pause().authority()), address(authority));
        assertEq(dssDeploy.pause().owner(), address(0));

        // dssDeploy
        assertEq(address(dssDeploy.authority()), address(0));
        assertEq(dssDeploy.owner(), msg.sender);
    }

    function checkReleasedAuth() internal {
        assertEq(vat.wards(address(dssDeploy)), 0, "vat auth not released");
        assertEq(cat.wards(address(dssDeploy)), 0, "cat auth not released");
        assertEq(dog.wards(address(dssDeploy)), 0, "dog auth not released");
        assertEq(vow.wards(address(dssDeploy)), 0, "vow auth not released");
        assertEq(jug.wards(address(dssDeploy)), 0, "jug auth not released");
        assertEq(pot.wards(address(dssDeploy)), 0, "pot auth not released");
        assertEq(dai.wards(address(dssDeploy)), 0, "dai auth not released");
        assertEq(spotter.wards(address(dssDeploy)), 0, "spotter auth not released");
        assertEq(flap.wards(address(dssDeploy)), 0, "flap auth not released");
        assertEq(flop.wards(address(dssDeploy)), 0, "flop auth not released");
        assertEq(cure.wards(address(dssDeploy)), 0, "cure auth not released");
        assertEq(end.wards(address(dssDeploy)), 0, "end auth not released");
        assertEq(phpClip.wards(address(dssDeploy)), 0, "phpClip auth not released");
        assertEq(usdtClip.wards(address(dssDeploy)), 0, "usdtClip auth not released");

    }
}