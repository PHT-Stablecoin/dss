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

import "./DssDeploy.t.base.pht.sol";

interface GemLike {
    function balanceOf(address) external view returns (uint256);
    function burn(uint256) external;
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

interface ProxyRegistryLike {
    function proxies(address) external view returns (address);
    function build(address) external returns (address);
}

interface ProxyLike {
    function owner() external view returns (address);
    function execute(address target, bytes memory data) external payable returns (bytes memory response);
}

/// New Interfaces Converted from Contracts

/**
 * @title CommonLike
 * @dev Interface for the Common contract
 */
interface CommonLike {
    function daiJoin_join(address apt, address urn, uint wad) external;
}

/**
 * @title DssProxyActionsLike
 * @dev Interface for the DssProxyActions contract, inheriting CommonLike
 */
interface DssProxyActionsLike is CommonLike {
    // Transfer Functions
    function transfer(address gem, address dst, uint amt) external;

    // Join Functions
    function ethJoin_join(address apt, address urn) external payable;
    function gemJoin_join(address apt, address urn, uint amt, bool transferFrom) external;

    // Permission Functions
    function hope(address obj, address usr) external;
    function nope(address obj, address usr) external;

    // CDP Management Functions
    function open(address manager, bytes32 ilk, address usr) external returns (uint cdp);
    function give(address manager, uint cdp, address usr) external;
    function giveToProxy(address proxyRegistry, address manager, uint cdp, address dst) external;
    function cdpAllow(address manager, uint cdp, address usr, uint ok) external;
    function urnAllow(address manager, address usr, uint ok) external;

    // CDP Operations
    function flux(address manager, uint cdp, address dst, uint wad) external;
    function move(address manager, uint cdp, address dst, uint rad) external;
    function frob(address manager, uint cdp, int dink, int dart) external;
    function quit(address manager, uint cdp, address dst) external;
    function enter(address manager, address src, uint cdp) external;
    function shift(address manager, uint cdpSrc, uint cdpOrg) external;

    // Bag Management
    function makeGemBag(address gemJoin) external returns (address bag);

    // Locking Collateral
    function lockETH(address manager, address ethJoin, uint cdp) external payable;
    function safeLockETH(address manager, address ethJoin, uint cdp, address owner) external payable;
    function lockGem(address manager, address gemJoin, uint cdp, uint amt, bool transferFrom) external;
    function safeLockGem(
        address manager,
        address gemJoin,
        uint cdp,
        uint amt,
        bool transferFrom,
        address owner
    ) external;

    // Freeing Collateral
    function freeETH(address manager, address ethJoin, uint cdp, uint wad) external;
    function freeGem(address manager, address gemJoin, uint cdp, uint amt) external;

    // Exiting Collateral
    function exitETH(address manager, address ethJoin, uint cdp, uint wad) external;
    function exitGem(address manager, address gemJoin, uint cdp, uint amt) external;

    // Debt Management
    function draw(address manager, address jug, address daiJoin, uint cdp, uint wad) external;
    function wipe(address manager, address daiJoin, uint cdp, uint wad) external;
    function safeWipe(address manager, address daiJoin, uint cdp, uint wad, address owner) external;
    function wipeAll(address manager, address daiJoin, uint cdp) external;
    function safeWipeAll(address manager, address daiJoin, uint cdp, address owner) external;

    // Combined Operations
    function lockETHAndDraw(
        address manager,
        address jug,
        address ethJoin,
        address daiJoin,
        uint cdp,
        uint wadD
    ) external payable;

    function openLockETHAndDraw(
        address manager,
        address jug,
        address ethJoin,
        address daiJoin,
        bytes32 ilk,
        uint wadD
    ) external payable returns (uint cdp);

    function lockGemAndDraw(
        address manager,
        address jug,
        address gemJoin,
        address daiJoin,
        uint cdp,
        uint amtC,
        uint wadD,
        bool transferFrom
    ) external;

    function openLockGemAndDraw(
        address manager,
        address jug,
        address gemJoin,
        address daiJoin,
        bytes32 ilk,
        uint amtC,
        uint wadD,
        bool transferFrom
    ) external returns (uint cdp);

    function openLockGNTAndDraw(
        address manager,
        address jug,
        address gntJoin,
        address daiJoin,
        bytes32 ilk,
        uint amtC,
        uint wadD
    ) external returns (address bag, uint cdp);

    // Wipe and Free Operations
    function wipeAndFreeETH(address manager, address ethJoin, address daiJoin, uint cdp, uint wadC, uint wadD) external;

    function wipeAllAndFreeETH(address manager, address ethJoin, address daiJoin, uint cdp, uint wadC) external;

    function wipeAndFreeGem(address manager, address gemJoin, address daiJoin, uint cdp, uint amtC, uint wadD) external;

    function wipeAllAndFreeGem(address manager, address gemJoin, address daiJoin, uint cdp, uint amtC) external;
}

/**
 * @title DssProxyActionsEndLike
 * @dev Interface for the DssProxyActionsEnd contract, inheriting CommonLike
 */
interface DssProxyActionsEndLike is CommonLike {
    // Freeing Collateral via End
    function freeETH(address manager, address ethJoin, address end, uint cdp) external;
    function freeGem(address manager, address gemJoin, address end, uint cdp) external;

    // Packing DAI
    function pack(address daiJoin, address end, uint wad) external;

    // Cashing Out Collateral
    function cashETH(address ethJoin, address end, bytes32 ilk, uint wad) external;
    function cashGem(address gemJoin, address end, bytes32 ilk, uint wad) external;
}

/**
 * @title DssProxyActionsDsrLike
 * @dev Interface for the DssProxyActionsDsr contract, inheriting CommonLike
 */
interface DssProxyActionsDsrLike is CommonLike {
    // Joining to DSR
    function join(address daiJoin, address pot, uint wad) external;

    // Exiting from DSR
    function exit(address daiJoin, address pot, uint wad) external;
    function exitAll(address daiJoin, address pot) external;
}

struct DssProxy {
    address Registry;
    address Actions;
    address ActionsDsr;
    address ActionsEnd;
}

// contract ProxyCalls {
//     ProxyLike proxy;
//     DssProxy dssProxy;

//     function transfer(address, address, uint256) public {
//         proxy.execute(dssProxy.Actions, msg.data);
//     }

//     function open(address, bytes32, address) public returns (uint cdp) {
//         bytes memory response = proxy.execute(dssProxy.Actions, msg.data);
//         assembly {
//             cdp := mload(add(response, 0x20))
//         }
//     }

//     function give(address, uint, address) public {
//         proxy.execute(dssProxy.Actions, msg.data);
//     }

//     function giveToProxy(address, address, uint, address) public {
//         proxy.execute(dssProxy.Actions, msg.data);
//     }

//     function cdpAllow(address, uint, address, uint) public {
//         proxy.execute(dssProxy.Actions, msg.data);
//     }

//     function urnAllow(address, address, uint) public {
//         proxy.execute(dssProxy.Actions, msg.data);
//     }

//     function hope(address, address) public {
//         proxy.execute(dssProxy.Actions, msg.data);
//     }

//     function nope(address, address) public {
//         proxy.execute(dssProxy.Actions, msg.data);
//     }

//     function flux(address, uint, address, uint) public {
//         proxy.execute(dssProxy.Actions, msg.data);
//     }

//     function move(address, uint, address, uint) public {
//         proxy.execute(dssProxy.Actions, msg.data);
//     }

//     function frob(address, uint, int, int) public {
//         proxy.execute(dssProxy.Actions, msg.data);
//     }

//     function frob(address, uint, address, int, int) public {
//         proxy.execute(dssProxy.Actions, msg.data);
//     }

//     function quit(address, uint, address) public {
//         proxy.execute(dssProxy.Actions, msg.data);
//     }

//     function enter(address, address, uint) public {
//         proxy.execute(dssProxy.Actions, msg.data);
//     }

//     function shift(address, uint, uint) public {
//         proxy.execute(dssProxy.Actions, msg.data);
//     }

//     function lockETH(address, address, uint) public payable {
//         (bool success,) = address(proxy).call{value: msg.value}(abi.encodeWithSignature("execute(address,bytes)", dssProxy.Actions, msg.data));
//         require(success, "");
//     }

//     function safeLockETH(address, address, uint, address) public payable {
//         (bool success,) = address(proxy).call{ value: msg.value}(abi.encodeWithSignature("execute(address,bytes)", dssProxy.Actions, msg.data));
//         require(success, "");
//     }

//     function lockGem(address, address, uint, uint, bool) public {
//         proxy.execute(dssProxy.Actions, msg.data);
//     }

//     function safeLockGem(address, address, uint, uint, bool, address) public {
//         proxy.execute(dssProxy.Actions, msg.data);
//     }

//     function makeGemBag(address) public returns (address bag) {
//         address payable target = payable(address(proxy));
//         bytes memory data = abi.encodeWithSignature("execute(address,bytes)", dssProxy.Actions, msg.data);
//         assembly {
//             let succeeded := call(sub(gas(), 5000), target, callvalue(), add(data, 0x20), mload(data), 0, 0)
//             let size := returndatasize()
//             let response := mload(0x40)
//             mstore(0x40, add(response, and(add(add(size, 0x20), 0x1f), not(0x1f))))
//             mstore(response, size)
//             returndatacopy(add(response, 0x20), 0, size)

//             bag := mload(add(response, 0x60))

//             switch iszero(succeeded)
//             case 1 {
//                 // throw if delegatecall failed
//                 revert(add(response, 0x20), size)
//             }
//         }
//     }

//     function freeETH(address, address, uint, uint) public {
//         proxy.execute(dssProxy.Actions, msg.data);
//     }

//     function freeGem(address, address, uint, uint) public {
//         proxy.execute(dssProxy.Actions, msg.data);
//     }

//     function exitETH(address, address, uint, uint) public {
//         proxy.execute(dssProxy.Actions, msg.data);
//     }

//     function exitGem(address, address, uint, uint) public {
//         proxy.execute(dssProxy.Actions, msg.data);
//     }

//     function draw(address, address, address, uint, uint) public {
//         proxy.execute(dssProxy.Actions, msg.data);
//     }

//     function wipe(address, address, uint, uint) public {
//         proxy.execute(dssProxy.Actions, msg.data);
//     }

//     function wipeAll(address, address, uint) public {
//         proxy.execute(dssProxy.Actions, msg.data);
//     }

//     function safeWipe(address, address, uint, uint, address) public {
//         proxy.execute(dssProxy.Actions, msg.data);
//     }

//     function safeWipeAll(address, address, uint, address) public {
//         proxy.execute(dssProxy.Actions, msg.data);
//     }

//     function lockETHAndDraw(address, address, address, address, uint, uint) public payable {
//         (bool success,) = address(proxy).call.value(msg.value)(abi.encodeWithSignature("execute(address,bytes)", dssProxy.Actions, msg.data));
//         require(success, "");
//     }

//     function openLockETHAndDraw(address, address, address, address, bytes32, uint) public payable returns (uint cdp) {
//         address payable target = payable(address(proxy));
//         bytes memory data = abi.encodeWithSignature("execute(address,bytes)", dssProxy.Actions, msg.data);
//         assembly {
//             let succeeded := call(sub(gas(), 5000), target, callvalue(), add(data, 0x20), mload(data), 0, 0)
//             let size := returndatasize()
//             let response := mload(0x40)
//             mstore(0x40, add(response, and(add(add(size, 0x20), 0x1f), not(0x1f))))
//             mstore(response, size)
//             returndatacopy(add(response, 0x20), 0, size)

//             cdp := mload(add(response, 0x60))

//             switch iszero(succeeded)
//             case 1 {
//                 // throw if delegatecall failed
//                 revert(add(response, 0x20), size)
//             }
//         }
//     }

//     function lockGemAndDraw(address, address, address, address, uint, uint, uint, bool) public {
//         proxy.execute(dssProxy.Actions, msg.data);
//     }

//     function openLockGemAndDraw(address, address, address, address, bytes32, uint, uint, bool) public returns (uint cdp) {
//         bytes memory response = proxy.execute(dssProxy.Actions, msg.data);
//         assembly {
//             cdp := mload(add(response, 0x20))
//         }
//     }

//     function openLockGNTAndDraw(address, address, address, address, bytes32, uint, uint) public returns (address bag, uint cdp) {
//         bytes memory response = proxy.execute(dssProxy.Actions, msg.data);
//         assembly {
//             bag := mload(add(response, 0x20))
//             cdp := mload(add(response, 0x40))
//         }
//     }

//     function wipeAndFreeETH(address, address, address, uint, uint, uint) public {
//         proxy.execute(dssProxy.Actions, msg.data);
//     }

//     function wipeAllAndFreeETH(address, address, address, uint, uint) public {
//         proxy.execute(dssProxy.Actions, msg.data);
//     }

//     function wipeAndFreeGem(address, address, address, uint, uint, uint) public {
//         proxy.execute(dssProxy.Actions, msg.data);
//     }

//     function wipeAllAndFreeGem(address, address, address, uint, uint) public {
//         proxy.execute(dssProxy.Actions, msg.data);
//     }

//     function end_freeETH(address a, address b, address c, uint d) public {
//         proxy.execute(dssProxy.ActionsEnd, abi.encodeWithSignature("freeETH(address,address,address,uint256)", a, b, c, d));
//     }

//     function end_freeGem(address a, address b, address c, uint d) public {
//         proxy.execute(dssProxy.ActionsEnd, abi.encodeWithSignature("freeGem(address,address,address,uint256)", a, b, c, d));
//     }

//     function end_pack(address a, address b, uint c) public {
//         proxy.execute(dssProxy.ActionsEnd, abi.encodeWithSignature("pack(address,address,uint256)", a, b, c));
//     }

//     function end_cashETH(address a, address b, bytes32 c, uint d) public {
//         proxy.execute(dssProxy.ActionsEnd, abi.encodeWithSignature("cashETH(address,address,bytes32,uint256)", a, b, c, d));
//     }

//     function end_cashGem(address a, address b, bytes32 c, uint d) public {
//         proxy.execute(dssProxy.ActionsEnd, abi.encodeWithSignature("cashGem(address,address,bytes32,uint256)", a, b, c, d));
//     }

//     function dsr_join(address a, address b, uint c) public {
//         proxy.execute(dssProxy.ActionsDsr, abi.encodeWithSignature("join(address,address,uint256)", a, b, c));
//     }

//     function dsr_exit(address a, address b, uint c) public {
//         proxy.execute(dssProxy.ActionsDsr, abi.encodeWithSignature("exit(address,address,uint256)", a, b, c));
//     }

//     function dsr_exitAll(address a, address b) public {
//         proxy.execute(dssProxy.ActionsDsr, abi.encodeWithSignature("exitAll(address,address)", a, b));
//     }
// }

contract DssDeployTestPHT is DssDeployTestBasePHT {
    DssProxy dssProxy;

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
            dog.file("PHP-A", "chop", 1.13e18); // Set the liquidation penalty (chop) for "PHP-A" to 13% (1.13e18 in WAD units)
            phpClip.file("buf", 1.20e27); // Set a 20% increase in auctions (RAY)
            vm.stopPrank();
        }

        address proxy = ProxyRegistryLike(dssProxy.Registry).build(address(this));
        assertEq(ProxyLike(proxy).owner(), address(this));

        {
            // Set Min Liquidiation Ratio = 105%
            proxyActions.file(address(spotter), "PHP-A", "mat", uint(1050000000 ether));
            spotter.poke("PHP-A");

            // Mint 2e12 php tokens (6 decimals)
            php.mint(1.20e6);
            assertEq(php.balanceOf(address(this)), 1.20e6);
            assertEq(vat.gem("PHP-A", address(this)), 0);

            // Approve proxy to spend 2e12 php tokens
            php.approve(address(proxy), 1.20e6);
            assertEq(php.allowance(address(this), address(proxy)), 1.20e6);
            assertEq(phpJoin.dec(), 6, "phpJoin.dec() should be 6");
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
            (uint256));

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

                ( /* clip */, uint chop, uint hole,) = dog.ilks("PHP-A");

                assertEq(usr, dssCdpManager.urns(cdpId));
                assertEq(tab, (chop * RAD) / WAD);
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
                assertEq(daiCollectedByVow, 1.13e45);
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
