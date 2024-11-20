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
    function safeLockGem(address manager, address gemJoin, uint cdp, uint amt, bool transferFrom, address owner) external;

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
    function wipeAndFreeETH(
        address manager,
        address ethJoin,
        address daiJoin,
        uint cdp,
        uint wadC,
        uint wadD
    ) external;

    function wipeAllAndFreeETH(
        address manager,
        address ethJoin,
        address daiJoin,
        uint cdp,
        uint wadC
    ) external;

    function wipeAndFreeGem(
        address manager,
        address gemJoin,
        address daiJoin,
        uint cdp,
        uint amtC,
        uint wadD
    ) external;

    function wipeAllAndFreeGem(
        address manager,
        address gemJoin,
        address daiJoin,
        uint cdp,
        uint amtC
    ) external;
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

    function setUp() override public {
        super.setUp();

        dssProxy.Registry = StdCheatsSafe.deployCode("lib/dss-proxy/src/DssProxyRegistry.sol:DssProxyRegistry");
        dssProxy.Actions = StdCheatsSafe.deployCode(
            "lib/dss-proxy-actions/src/DssProxyActions.sol:DssProxyActions"
        );
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
    function testLiquidation() public {
        deployKeepAuth(address(dssDeploy));

        address proxy = ProxyRegistryLike(dssProxy.Registry).build(address(this));
        assertEq(ProxyLike(proxy).owner(), address(this));

        php.mint(2 ether);
        assertEq(php.balanceOf(address(this)), 2 ether);
        assertEq(vat.gem("PHP-A", address(this)), 0);

        php.approve(address(proxy), 2 ether);
        
        ProxyLike(proxy).execute(
            dssProxy.Actions,
            abi.encodeWithSelector(
                DssProxyActionsLike.gemJoin_join.selector,
                proxy, proxy, 2 ether, true));
        
        // phpJoin.join(address(this), 2 ether);

        assertEq(php.balanceOf(address(this)), 0);
        assertEq(vat.gem("PHP-A", proxy), 2 ether);

        // Set Min Liquidiation Ratio = 105%
        proxyActions.file(address(spotter), "PHP-A", "mat", uint(1050000000 ether));
        spotter.poke("PHP-A");

        // Borrow at 105%

        // vat.frob("PHP-A", address(this), address(this), address(this), 1.2 ether, 1 ether);
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
