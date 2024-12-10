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

import {StdCheatsSafe} from "forge-std/StdCheats.sol";
import {
    CommonLike,
    DssProxyActionsDsrLike,
    DssProxyActionsLike,
    DssProxyActionsEndLike
    } from "./interfaces/IDssProxyActions.sol";

import "./DssDeploy.t.base.pht.sol";

interface ProxyRegistryLike {
    function proxies(address) external view returns (address);
    function build(address) external returns (address);
}

interface ProxyLike {
    function owner() external view returns (address);
    function execute(address target, bytes memory data) external payable returns (bytes memory response);
}


contract DssDeployTestPHT is DssDeployTestBasePHT {
    DssProxy dssProxy;

    struct DssProxy {
        address Registry;
        address Actions;
        address ActionsDsr;
        address ActionsEnd;
    }

    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x, "sub-overflow");
    }

    function toInt(uint x) internal pure returns (int y) {
        y = int(x);
        require(y >= 0, "int-overflow");
    }

    function toRad(uint wad) internal pure returns (uint rad) {
        rad = mul(wad, 10 ** 27);
    }

    function setUp() public override {
        super.setUp();

        dssProxy.Registry = StdCheatsSafe.deployCode("lib/dss-proxy/src/DssProxyRegistry.sol:DssProxyRegistry");
        dssProxy.Actions = StdCheatsSafe.deployCode("lib/dss-proxy-actions/src/DssProxyActions.sol:DssProxyActions");
        dssProxy.ActionsEnd = StdCheatsSafe.deployCode(
            "lib/dss-proxy-actions/src/DssProxyActions.sol:DssProxyActionsEnd"
        );
        dssProxy.ActionsDsr = StdCheatsSafe.deployCode(
            "lib/dss-proxy-actions/src/DssProxyActions.sol:DssProxyActionsDsr"
        );
    }

    function testAuth() public {
        deployKeepAuth(address(dssDeploy));
        checkAuth();

        // Release Auth
        dssDeploy.releaseAuth(address(dssDeploy));
        dssDeploy.releaseAuthClip("PHP-A", address(dssDeploy));
        dssDeploy.releaseAuthClip("USDT-A", address(dssDeploy));
        checkReleasedAuth();
    }

    function testDeployProxyActions() public {
        deployKeepAuth(address(dssDeploy));

        address proxy = ProxyRegistryLike(dssProxy.Registry).build(address(this));
        assertEq(ProxyLike(proxy).owner(), address(this));
    }

    function testLiquidation_addCollateral_JointFeed() public {
        deployKeepAuth(address(dssDeploy));
        checkAuth();

        (PriceFeedAggregator feedAToB, ) = feedFactory.create(6, 3e6, "A/USD"); // 1 Token A = 3 USD;
        (PriceFeedAggregator feedBToPHT,) = feedFactory.create(6, 2e6, "PHT/USD"); // 1 PHT = 2 USD;
        
        (
            ,
            PriceFeedAggregator feedAToPHT,
            ,
            ChainlinkPip pipTokenA
        ) = dssDeploy.addCollateral(
            proxyActions,
            ilkRegistry,
            DssDeployExt.IlkParams({
                ilk: "Token-A",
                line: uint(10000 * 10 ** 45),
                dust: uint(0),
                tau: 1 hours,
                mat: uint(1500000000 ether), // mat: Liquidation Ratio (150%),
                hole: 5_000_000 * RAD, // Set USDT-A limit to 5 million DAI (RAD units)
                chop: 1.13e18, // Set the liquidation penalty (chop) for "USDT-A" to 13% (1.13e18 in WAD units)
                buf: 1.20e27, // Set a 20% increase in auctions (RAY)
                duty: 1.0000000018477e27 // 0.00000018477% => 6% Annual duty
            }),
            DssDeployExt.TokenParams({
                token: address(0),
                symbol: "tknA",
                name: "Token A",
                decimals: 18,
                maxSupply: 0
            }),
            DssDeployExt.FeedParams({
                factory: feedFactory,
                joinFactory: joinFeedFactory,
                feed: address(0),
                decimals: 0,
                initialPrice: int(0),
                numeratorFeed: address(feedAToB),
                invertNumerator: false,
                denominatorFeed: address(feedBToPHT),
                invertDenominator: false,
                feedDescription: "A/PHT"
            })
        );

        (, int256 answer,,,) = feedAToPHT.latestRoundData();
        assertEq(answer, int(1.5e8), "1 Token A  = 6 PHT");
    }

    /**
     * Test: liquidate Vault by paying PHT and receiving the collateral (PHP)
     * - Min collateral ratio 105%
     * - simulate price drop to make collateral ratio of Vault to 103%
     * - show where the surplus 3% is going (Vow contract)
     **/
    function testLiquidation_openLockGemAndDraw() public {
        deployKeepAuth(address(dssDeploy));
        checkAuth();

        {
            // Set global and per-collateral liquidation limits
            vm.startPrank(address(dssDeploy));
            dog.file("Hole", 10_000_000 * RAD); // Set global limit to 10 million DAI (RAD units)
            dog.file("PHP-A", "hole", 5_000_000 * RAD); // Set PHP-A limit to 5 million DAI (RAD units)
            dog.file("PHP-A", "chop", 1.13 *10e18); // Set the liquidation penalty (chop) for "PHP-A" to 13% (1.13e18 in WAD units)
            phpClip.file("buf", 1.20 * 10e27); // Set a 20% increase in auctions (RAY)
            vm.stopPrank();
        }

        (uint256 phpDuty,) = jug.ilks("PHP-A");
        console.log("phpDuty", phpDuty);
        console.log("base", jug.base());

        // assertLt(phpDuty + jug.base(), uint(1.2e27));


        address proxy = ProxyRegistryLike(dssProxy.Registry).build(address(this));
        assertEq(ProxyLike(proxy).owner(), address(this));

        {
            // Set Min Liquidiation Ratio = 105%
            proxyActions.file(address(spotter), "PHP-A", "mat", uint(1050000000 ether));
            spotter.poke("PHP-A");

            // Mint 2e12 php tokens (6 decimals)
            php.mint(1.20 * 10e6);
            assertEq(php.balanceOf(address(this)), 1.20 * 10e6);
            assertEq(vat.gem("PHP-A", address(this)), 0);

            // Approve proxy to spend 2e12 php tokens
            php.approve(address(proxy), 1.20* 10e6);
            assertEq(php.allowance(address(this), address(proxy)), 1.20 *10e6);
            assertEq(phpJoin.dec(), 6, "phpJoin.dec() should be 6");
        }

        {
            // Move Blocktime to 10 blocks ahead
            vm.warp(now + 100);
        }

        // Call openLockGemAndDraw with correct amtC
        uint256 cdpId = abi.decode(
            ProxyLike(proxy).execute(
                dssProxy.Actions,
                abi.encodeWithSelector(
                    DssProxyActionsLike.openLockGemAndDraw.selector,
                    address(dssCdpManager),
                    address(jug),
                    address(phpJoin),
                    address(daiJoin),
                    bytes32("PHP-A"),
                    uint(1.06e6),
                    uint(1e18), // Drawing 1 DAI (18 decimals)
                    true
                )
            ),
            (uint256)
        );

        {
            // Collateral owned by Join
            assertEq(php.balanceOf(address(phpJoin)), 1.06e6);
            // After operation, balance should be zero
            assertEq(vat.gem("PHP-A", address(proxy)), 0);
            // Collateral owned by cdpId also zero
            assertEq(vat.gem("PHP-A", dssCdpManager.urns(cdpId)), 0);
            // Dai (PHT) is transferred to proxy
            assertEq(dai.balanceOf(address(this)), 1e18);
            // Gem ownership in urnhandler
            assertEq(vat.gem("PHP-A", address(this)), 0);
        }

        {
            // Simulate a price drop to reduce collateralization from 105% to 102%
            uint256 newPrice = uint256(1e6 * 102) / uint256(105); // New price ≈ 971428
            feedPHP.file("answer", int(newPrice)); // Price 1 DAI (PHT) = 1 PHP (precision 6)
            // Trigger a liquidation
            spotter.poke("PHP-A");
        }

        {
            (uint256 ink, uint256 art) = vat.urns("PHP-A", dssCdpManager.urns(cdpId));
            (, uint256 rate, uint256 spot, , uint256 dust) = vat.ilks("PHP-A");

            (address clip, uint chop, uint hole, uint dirt) = dog.ilks("PHP-A");
            console.log("dog.Hole", uint256(dog.Hole()));
            console.log("dog.Dirt", uint256(dog.Dirt()));
            console.log("dog.ilk.hole", uint256(hole));
            console.log("dog.ilk.dirt", uint256(dirt));
            console.log("dog.ilk.chop", uint256(chop));
            console.log("ink", ink); // Collateral
            console.log("art", art); // Dai
            console.log("spot", spot); //
            console.log("rate", rate);
            console.log("ink*spot", ink * spot);
            console.log("art*rate", art * rate);
        }

        //0x555344432d4100000000000000000
        //0x555344432d410000000000000000000000000000000000000000000000000000
        //15000000000000000000000000000000000000000000000000
        {
            // Run Auction on Liquidation owned by UrnHandler
            uint256 auctionId = dog.bark("PHP-A", dssCdpManager.urns(cdpId), address(0));

            // Check Clip Auction is Created
            (uint256 pos, uint256 tab, uint256 lot, address usr, uint96 tic, uint256 top) = phpClip.sales(auctionId);

            {
                console.log("phpClip.sales(auctionId).pos", pos);
                console.log("phpClip.sales(auctionId).tab", tab);
                console.log("phpClip.sales(auctionId).lot", lot);
                console.log(uint256(tic));
                console.logAddress(usr);

                (, /* clip */ uint chop, uint hole, ) = dog.ilks("PHP-A");

                assertEq(usr, dssCdpManager.urns(cdpId), "user owns urn");
                assertEq(lot, 1.06e18); //wad
            }

            // Record collateral in the urn before liquidation
            (uint256 urnInkBefore, ) = vat.urns("PHP-A", dssCdpManager.urns(cdpId));
            console.log("Urn collateral before liquidation (WAD units):", urnInkBefore);

            // Record the vow's DAI balance after liquidation
            uint256 vowSinBefore = vat.sin(address(vow));
            console.log("Vow Sin balance before auction (RAD units):", vowSinBefore);

            uint256 vowDaiBefore = vat.dai(address(vow));
            console.log("Vow DAI balance before auction (RAD units):", vowDaiBefore);

            /// Keeper Action as Auction Member
            /// (See dss-cron/src/LiquidatorJob.sol)
            vm.startPrank(address(dssDeploy));
            {
                // Create internal DAI using suck
                // Calculate the amount owed (owe) before calling vat.suck
                // slice = lot: Assuming time elapsed is zero
                // price = top: Full amount of collateral
                // buf ; Initial auction price increase;
                vat.suck(
                    address(vat),
                    address(dssDeploy),
                    mul(lot, top) // owe = slice * price
                );
                // Give permission to clipper
                if (vat.can(address(dssDeploy), address(phpClip)) != 1) {
                    vat.hope(address(phpClip));
                }
                // Give permission to vow
                if (vat.can(address(dssDeploy), address(vow)) != 1) {
                    vat.hope(address(vow));
                }

                bytes memory empty;
                phpClip.take(
                    auctionId, //id
                    uint(-1), //amt
                    top, //max
                    address(dssDeploy),
                    empty
                );

                console.log("Bought collateral (WAD)", vat.gem("PHP-A", address(dssDeploy)));
            }

            vm.stopPrank();

            {
                // Record collateral in the urn after auction
                (uint256 urnInkAfter, ) = vat.urns("PHP-A", dssCdpManager.urns(cdpId));
                console.log("Urn collateral after auction (WAD units):", urnInkAfter);

                // Record the vow's DAI balance after liquidation
                console.log("Vow DAI balance after auction (RAD units):", vat.sin(address(vow)));
                console.log("Vow DAI balance after auction (RAD units):", vat.dai(address(vow)));

                uint256 daiCollectedByVow = vat.dai(address(vow)) - vowDaiBefore;
                
                assertGt(daiCollectedByVow, 1.13e45, "daiCollectedByVow greater than original mint");
                uint256 sinIncreased = vat.sin(address(vow)) - vowSinBefore;
                assertEq(sinIncreased, 0, "Sin has not increased");
                uint256 surplus = daiCollectedByVow - 1e45;

                console.log("DAI collected by Vow (RAD units):", daiCollectedByVow);
                console.log("System debt increased (RAD units):", sinIncreased);
                console.log("Surplus with liquidation penalty (RAD units):", surplus);
            }
        }
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
        assertEq(dssDeploy.owner(), address(this));
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
