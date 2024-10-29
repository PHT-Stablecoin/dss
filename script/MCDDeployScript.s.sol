// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "forge-std/Script.sol";
import "forge-std/Test.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Core contracts
import {Vat} from "dss/vat.sol";
import {Jug} from "dss/jug.sol";
import {Vow} from "dss/vow.sol";
import {Cat} from "dss/cat.sol";
import {Dog} from "dss/dog.sol";
import {Dai} from "dss/dai.sol";
import {DaiJoin} from "dss/join.sol";
import {Flapper} from "dss/flap.sol";
import {Flopper} from "dss/flop.sol";
import {Flipper} from "dss/flip.sol";
import {Clipper} from "dss/clip.sol";
import {GemJoin} from "dss/join.sol";
import {Spotter} from "dss/spot.sol";
import {End} from "dss/end.sol";

// Test Tokens
contract XINF is
    ERC20 // Governance Token (MKR)
{
    constructor(uint256 initialSupply) public ERC20("Infinex Token", "XINF") {
        _mint(msg.sender, initialSupply);
    }

    address public gov;
    function setGov(address _gov) external {
        require(msg.sender == gov || gov == address(0), "XINF/not-authorized");
        gov = _gov;
    }
}

contract TestUSDT is
    ERC20 // Collateral Token (USDT)
{
    constructor(uint256 initialSupply) public ERC20("Test USDT", "tstUSDT") {
        _mint(msg.sender, initialSupply);
    }

    function decimals() public view virtual override returns (uint8) {
        return 6;
    }
}

// Oracle Mock for Testing
contract DSValue {
    bytes32 public value;
    function setValue(uint256 val) external {
        value = bytes32(val);
    }
    function read() external view returns (bytes32) {
        return value;
    }

    function peek() external view returns (bytes32, bool) {
        return (value, true);
    }
}

contract MCDDeployScript is Script, Test {
    // System Parameters
    uint256 constant RAY = 10 ** 27;
    uint256 constant WAD = 10 ** 18;
    uint256 constant RAD = 10 ** 45;
    // Total debt ceiling - needs to be in RAD
    uint256 constant LINE = 10000000 * RAD;
    // USDT debt ceiling - needs to be in RAD
    uint256 constant USDT_LINE = 5000000 * RAD;
    // USDT Liquidation ratio (200%) - needs to be in RAY
    uint256 constant USDT_MAT = 2 * RAY;
    // Stability fee (4% yearly) - already correct in RAY
    uint256 constant DUTY = 1000000001243680656318820312;
    // Liquidation penalty (13%) - needs to be in WAD
    uint256 constant CHOP = 113 * 10 ** 16; // 1.13 * WAD

    // Governance Parameters
    uint256 constant INITIAL_XINF_SUPPLY = 1000000 * WAD;
    uint256 constant INITIAL_USDT_SUPPLY = 10000000 * (10 ** 6); // USDT has 6 decimals
    // Minimum bid increase (3%) - needs to be in WAD
    uint256 constant BEG = 103 * 10 ** 16; // 1.03 * WAD
    uint256 constant TTL = 3 hours;
    uint256 constant TAU = 2 days;

    // Deployed contract addresses
    Vat public vat;
    Dai public dai;
    DaiJoin public daiJoin;
    XINF public xinf;
    TestUSDT public usdt;
    GemJoin public usdtJoin;
    Jug public jug;
    Vow public vow;
    Dog public dog;
    Spotter public spot;
    DSValue public usdtPip;
    Clipper public usdtClip;

    function run() external {
        vm.startBroadcast();

        // Deploy Tokens
        xinf = new XINF(INITIAL_XINF_SUPPLY);
        usdt = new TestUSDT(INITIAL_USDT_SUPPLY);

        // Deploy Core System
        vat = new Vat();
        dai = new Dai(0); // chainId
        daiJoin = new DaiJoin(address(vat), address(dai));
        jug = new Jug(address(vat));

        // Deploy Auction Modules
        Flapper flap = new Flapper(address(vat), address(xinf));
        Flopper flop = new Flopper(address(vat), address(xinf));

        // Deploy System Modules
        vow = new Vow(address(vat), address(flop), address(flap));
        dog = new Dog(address(vat));
        spot = new Spotter(address(vat));

        // Deploy End (Emergency Shutdown)
        End end = new End();
        end.file("vat", address(vat));
        end.file("dog", address(dog));
        end.file("vow", address(vow));
        end.file("spot", address(spot));

        // Initialize USDT as Collateral
        vat.init("USDT-A");
        vat.file("Line", LINE);
        vat.file("USDT-A", "line", USDT_LINE);
        vat.file("USDT-A", "dust", 100 * RAD); // 100 DAI minimum

        // Setup USDT Join Adapter
        usdtJoin = new GemJoin(address(vat), "USDT-A", address(usdt));
        vat.rely(address(usdtJoin));

        // Setup Liquidation with correct units
        dog.file("USDT-A", "chop", CHOP);
        dog.file("USDT-A", "hole", 5000 * RAD);

        // Setup Stability Fee
        jug.init("USDT-A");
        jug.file("USDT-A", "duty", DUTY);

        // Setup Price Feed
        // need to auth spotter before we can poke
        vat.rely(address(spot));

        // Setup Price Feed with correct decimal handling
        // Deploy Price Oracle Mock
        usdtPip = new DSValue();

        usdtPip.setValue(1 * (10 ** uint256(usdt.decimals()))); // 1 USDT = $1
        spot.file("USDT-A", "pip", address(usdtPip));
        spot.file("USDT-A", "mat", USDT_MAT); // Already in RAY
        spot.poke("USDT-A");

        // Deploy Liquidation Auction
        usdtClip = new Clipper(
            address(vat),
            address(spot),
            address(dog),
            "USDT-A"
        );
        dog.rely(address(usdtClip));
        usdtClip.file("vow", address(vow));

        // Setup Clipper parameters
        // buf (Maximum price multiplier 20%) - needs to be in RAY
        usdtClip.file("buf", 120 * 10 ** 25); // 1.2 * RAY
        usdtClip.file("tail", 3 hours);
        // cusp (Percentage drop before reset) - needs to be in RAY
        usdtClip.file("cusp", 60 * 10 ** 25); // 0.6 * RAY
        // chip (Percentage for keeper reward) - needs to be in WAD
        usdtClip.file("chip", 1 * 10 ** 16); // 0.01 * WAD
        // tip (Flat fee for keeper reward) - needs to be in RAD
        usdtClip.file("tip", 100 * RAD);

        // Auth Setup
        vat.rely(address(daiJoin));
        vat.rely(address(jug));
        vat.rely(address(spot));
        vat.rely(address(dog));
        vat.rely(address(end));
        vat.rely(address(flap));
        vat.rely(address(flop));
        dai.rely(address(daiJoin));
        xinf.setGov(msg.sender);

        flap.rely(address(vow));
        flop.rely(address(vow));

        vm.stopBroadcast();

        // Run post-deployment checks
        checkDeployment();
    }

    function checkDeployment() internal {
        console.log("\nRunning post-deployment checks...");

        address user = address(0x1);
        address liquidator = address(0x2);
        uint256 usdtAmount = 1000 * (10 ** uint256(usdt.decimals())); // 1000 USDT

        // Need to call drip to update rate to current time
        jug.drip("USDT-A");
        (, uint256 rate, , , ) = vat.ilks("USDT-A");
        console.log("Rate:", rate);

        uint256 drawAmount = 100 * WAD;

        console.log("Usdt amount:", usdtAmount);
        console.log("Draw amount:", drawAmount);

        // Setup test scenario
        vm.startPrank(address(msg.sender));
        usdt.transfer(user, usdtAmount);
        xinf.transfer(liquidator, 1000 * WAD);
        vm.stopPrank();

        // User approves and joins USDT
        vm.startPrank(user);
        usdt.approve(address(usdtJoin), usdtAmount);
        usdtJoin.join(user, usdtAmount);

        // check join worked correctly
        assertEq(
            IERC20(address(usdt)).balanceOf(address(usdtJoin)),
            usdtAmount
        );

        assertEq(
            vat.gem("USDT-A", user),
            usdtAmount,
            "Vat: Incorrect collateral amount deposited"
        );

        // User opens vault and draws DAI
        (uint256 ink, uint256 art) = vat.urns("USDT-A", user);
        require(ink == 0 && art == 0, "Vault should start empty");

        // First, approve the vat to manipulate user's USDT
        vat.hope(address(usdtJoin));
        // Debug prints before frob
        console.log("Initial state:");
        console.log("Collateral to lock (ink):", usdtAmount);
        console.log("DAI to generate (art):", drawAmount);
        bytes32 ilk = "USDT-A";
        (uint256 Art, , uint256 Spot, , ) = vat.ilks(ilk);
        console.log("Current ilk Art:", Art);
        console.log("Current ilk Spot:", Spot);
        vat.frob(
            "USDT-A",
            user,
            user,
            user,
            int256(usdtAmount),
            int256(drawAmount) // Convert to correct unit for art
        );

        // Verify vault state
        (ink, art) = vat.urns("USDT-A", user);
        require(ink == usdtAmount, "Incorrect collateral amount");
        require(art == drawAmount, "Incorrect debt amount");

        console.log("Vault opened successfully");
        console.log("Collateral: ", ink);
        console.log("Debt: ", art);

        vm.stopPrank();

        // For price drop test, set price in WAD
        usdtPip.setValue(8 * 10 ** 17); // 0.80 USD in WAD
        spot.poke("USDT-A");

        console.log("\nPrice dropped to $0.80, checking liquidation...");

        // Liquidator takes action
        vm.startPrank(liquidator);
        uint256 id = dog.bark("USDT-A", user, address(liquidator));
        require(id > 0, "Liquidation should succeed");

        // Verify vault state after liquidation
        (ink, art) = vat.urns("USDT-A", user);
        require(ink == 0, "Vault should be emptied");
        require(art == 0, "Debt should be cleared");

        console.log("Liquidation successful");
        console.log("Final ink: ", ink);
        console.log("Final art: ", art);
        vm.stopPrank();

        console.log("\nAll post-deployment checks passed!");
    }

    // Convert token amount to dink
    function tokenToWad(
        uint256 amount,
        uint8 decimals
    ) private pure returns (uint256) {
        return amount * 10 ** (18 - uint256(decimals));
    }

    // Convert DAI amount to dart
    function daiToRay(
        uint256 daiAmount,
        uint256 rate
    ) private pure returns (uint256) {
        return (daiAmount * RAY) / rate;
    }

    function ray(uint256 wad) internal pure returns (uint256) {
        return wad * 10 ** 9;
    }
    function rad(uint256 wad) internal pure returns (uint256) {
        return wad * 10 ** 27;
    }
}
