// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.6.12;

import "forge-std/Script.sol";
import "forge-std/console.sol";

// Core contracts
import {Vat} from "../src/vat.sol";
import {Jug} from "../src/jug.sol";
import {Vow} from "../src/vow.sol";
import {Cat} from "../src/cat.sol";
import {Dog} from "../src/dog.sol";
import {Dai} from "../src/dai.sol";
import {DaiJoin} from "../src/join.sol";
import {Flapper} from "../src/flap.sol";
import {Flopper} from "../src/flop.sol";
import {Flipper} from "../src/flip.sol";
import {Clipper} from "../src/clip.sol";
import {GemJoin} from "../src/join.sol";
import {Spotter} from "../src/spot.sol";
import {End} from "../src/end.sol";

contract MCDDeployScript is Script {
    // System Parameters
    uint256 constant LINE = 10000000 ether; // Total debt ceiling
    uint256 constant ILKS_LINE = 5000000 ether; // Individual collateral debt ceiling
    uint256 constant MAT = 1.5e27; // Liquidation ratio (150%)
    uint256 constant DUTY = 1.05e27; // Stability fee (5%)
    uint256 constant CHOP = 1.13e27; // Liquidation penalty (13%)

    // @TODO parameterize this or get from chain
    uint256 constant CHAIN_ID = 1;

    function run() external {
        // Deploy core contracts
        vm.startBroadcast();

        // Deploy Core System
        Vat vat = new Vat();
        Dai dai = new Dai(CHAIN_ID);
        DaiJoin daiJoin = new DaiJoin(address(vat), address(dai));
        Jug jug = new Jug(address(vat));
        Vow vow = new Vow(address(vat), address(0), address(0)); // Update flap/flop later
        Dog dog = new Dog(address(vat));
        Spotter spotter = new Spotter(address(vat));

        // Deploy Price Feed Module
        // Note: In production, you'd want to deploy actual price feeds
        // This is a simplified example

        // Deploy Liquidation Module
        Flapper flap = new Flapper(address(vat), address(dai));
        Flopper flop = new Flopper(address(vat), address(0)); // gov token

        // Update Vow addresses
        vow.file("flapper", address(flap));
        vow.file("flopper", address(flop));

        // Deploy End (Emergency Shutdown)
        End end = new End();
        end.file("vat", address(vat));
        end.file("cat", address(0)); // Legacy
        end.file("dog", address(dog));
        end.file("vow", address(vow));
        end.file("spot", address(spotter));

        // Initialize Core System
        vat.init("USDT-A"); // Initialize first collateral type
        vat.file("Line", LINE); // Set total debt ceiling
        vat.file("USDT-A", "line", ILKS_LINE); // Set collateral debt ceiling
        vat.file("USDT-A", "dust", 100 ether); // Minimum debt size

        // Setup Liquidation Parameters
        dog.file("USDT-A", "chop", CHOP);
        dog.file("USDT-A", "hole", 5000 ether);

        // Setup Stability Fee
        jug.init("USDT-A");
        jug.file("USDT-A", "duty", DUTY);

        // Setup Price Feed
        spotter.file("USDT-A", "mat", MAT);

        // Auth Setup
        vat.rely(address(daiJoin));
        vat.rely(address(jug));
        vat.rely(address(spotter));
        vat.rely(address(dog));
        vat.rely(address(end));

        dai.rely(address(daiJoin));

        // Deploy Collateral Adapter
        // Note: In production, you'd deploy actual collateral tokens
        GemJoin ethJoin = new GemJoin(address(vat), "USDT-A", address(dai));
        vat.rely(address(ethJoin));

        // Deploy Liquidation Auction Contract
        Clipper clip = new Clipper(
            address(vat),
            address(spotter),
            address(dog),
            "USDT-A"
        );
        dog.rely(address(clip));
        clip.file("vow", address(vow));

        // Additional system parameters
        vat.file("USDT-A", "dust", 100 ether); // Minimum debt size
        clip.file("buf", 1.2e27); // Liquidation penalty
        clip.file("tail", 3 hours); // Max auction duration
        clip.file("cusp", 0.4e27); // Percentage drop before reset
        clip.file("chip", 0.02e27); // Percentage for keeper reward
        clip.file("tip", 100 ether); // Flat fee for keeper reward

        vm.stopBroadcast();

        // Log deployed addresses
        console.log("Core Contracts:");
        console.log("VAT:", address(vat));
        console.log("DAI:", address(dai));
        console.log("DAI_JOIN:", address(daiJoin));
        console.log("JUG:", address(jug));
        console.log("VOW:", address(vow));
        console.log("DOG:", address(dog));
        console.log("SPOTTER:", address(spotter));
        console.log("END:", address(end));
        console.log("FLAP:", address(flap));
        console.log("FLOP:", address(flop));
        console.log("");
        console.log("Collateral Specific:");
        console.log("USDT_JOIN:", address(ethJoin));
        console.log("USDT_CLIP:", address(clip));
    }
}
