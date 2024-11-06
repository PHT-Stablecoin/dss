pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "forge-std/Script.sol";
import "forge-std/Test.sol";
import "forge-std/console.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {DSAuth, DSAuthority} from "ds-auth/auth.sol";
import {DSTest} from "ds-test/test.sol";
import {DSToken} from "ds-token/token.sol";
import {DSValue} from "ds-value/value.sol";
import {GemJoin} from "dss/join.sol";
import {LinearDecrease} from "dss/abaci.sol";

import {GovActions} from "../test/helpers/govActions.sol";

import "../test/helpers/DssDeploy.sol";
import {FakeUser} from "../test/helpers/FakeUser.sol";
import {MockGuard} from "../test/helpers/MockGuard.sol";
import {ProxyActions} from "../test/helpers/ProxyActions.sol";
import {WETH} from "../test/helpers/WETH.sol";
import {TestUSDT} from "../test/helpers/USDT.sol";
import {XINF} from "../test/helpers/XINF.sol";

import {ChainLog} from "../test/helpers/ChainLog.sol";

// Chainlink
import {MockAggregatorV3} from "../test/helpers/MockAggregatorV3.sol";
import {ChainlinkPip, AggregatorV3Interface} from "../test/helpers/ChainlinkPip.sol";

contract DssDeployScript is Script, Test {
    VatFab vatFab;
    JugFab jugFab;
    VowFab vowFab;
    CatFab catFab;
    DogFab dogFab;
    DaiFab daiFab;
    DaiJoinFab daiJoinFab;
    FlapFab flapFab;
    FlopFab flopFab;
    FlipFab flipFab;
    ClipFab clipFab;
    CalcFab calcFab;
    SpotFab spotFab;
    PotFab potFab;
    CureFab cureFab;
    EndFab endFab;
    ESMFab esmFab;
    PauseFab pauseFab;

    DssDeploy dssDeploy;
    ProxyActions proxyActions;

    DSToken gov;
    DSValue pipETH;
    DSValue pipUSDT;
    DSValue pipPHS;
    DSValue pipXINF;
    
    ChainlinkPip pipCOL3;
    MockAggregatorV3 feedCOL3;

    MockGuard authority;

    IERC20 weth;
    IERC20 usdt;
    GemJoin ethJoin;
    GemJoin colJoin;
    GemJoin col2Join;

    Vat vat;
    Jug jug;
    Vow vow;
    Cat cat;
    Dog dog;
    Flapper flap;
    Flopper flop;
    Dai dai;
    GemJoin usdtJoin;
    GemJoin phsJoin;
    DaiJoin daiJoin;
    Spotter spotter;
    Pot pot;
    Cure cure;
    End end;
    ESM esm;

    Clipper ethClip;
    Flipper ethFlip;
    Clipper usdtClip;
    Clipper phsClip;

    ChainLog clog;
    
    // --- Math ---
    uint256 constant WAD = 10 ** 18;
    uint256 constant RAY = 10 ** 27;
    uint256 constant RAD = 10 ** 45;

    // Governance Parameters
    uint256 constant INITIAL_XINF_SUPPLY = 1000000 * WAD;
    uint256 constant INITIAL_USDT_SUPPLY = 10000000 * (10 ** 6); // USDT has 6 decimals

    // TOKENS
    address constant MAINNET_USDT_ADDR = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant MAINNET_WETH_ADDR = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x);
    }

    function run() public {
        vm.startBroadcast();

        setUp();
        deployKeepAuth(address(dssDeploy));
        this.testAuth();

        // Release Auth
        dssDeploy.releaseAuth(address(dssDeploy));
        dssDeploy.releaseAuthFlip("ETH", address(dssDeploy));
        dssDeploy.releaseAuthClip("USDT-A", address(dssDeploy));
        this.testReleasedAuth();

        // artifacts
        string memory root = vm.projectRoot();
        string memory path = string(abi.encodePacked(root, "/script/output/1/dssDeploy.artifacts.json"));
        string memory artifacts = "artifacts";
        vm.serializeAddress(artifacts, "clog", address(clog));
        vm.serializeAddress(artifacts, "usdt", address(usdt));
        vm.serializeAddress(artifacts, "weth", address(weth));
        vm.serializeAddress(artifacts, "spot", address(spotter));
        vm.serializeAddress(artifacts, "jug", address(jug));
        vm.serializeAddress(artifacts, "vat", address(vat));
        vm.serializeAddress(artifacts, "flop", address(flop));
        vm.serializeAddress(artifacts, "flap", address(flap));
        vm.serializeAddress(artifacts, "vow", address(vow));

        string memory output = vm.serializeAddress(artifacts, "dssDeploy", address(dssDeploy));
        vm.writeJson(output, path);

        vm.stopBroadcast();
    }

    function setUp() public virtual {
        vatFab = new VatFab();
        jugFab = new JugFab();
        vowFab = new VowFab();
        catFab = new CatFab();
        dogFab = new DogFab();
        daiFab = new DaiFab();
        daiJoinFab = new DaiJoinFab();
        flapFab = new FlapFab();
        flopFab = new FlopFab();
        flipFab = new FlipFab();
        clipFab = new ClipFab();
        calcFab = new CalcFab();
        spotFab = new SpotFab();
        potFab = new PotFab();
        cureFab = new CureFab();
        endFab = new EndFab();
        esmFab = new ESMFab();
        pauseFab = new PauseFab();

        dssDeploy = new DssDeploy();

        dssDeploy.addFabs1(vatFab, jugFab, vowFab, catFab, dogFab, daiFab, daiJoinFab);

        dssDeploy.addFabs2(
            flapFab,
            flopFab,
            flipFab,
            clipFab,
            calcFab,
            spotFab,
            potFab,
            cureFab,
            endFab,
            esmFab,
            pauseFab
        );

        gov = new DSToken("GOV");

        // TODO
        gov.setAuthority(DSAuthority(address(new MockGuard())));
        pipETH = new DSValue();
        pipUSDT = new DSValue();
        pipXINF = new DSValue();
        authority = new MockGuard();

        feedCOL3 = new MockAggregatorV3();
        pipCOL3 = new ChainlinkPip(address(feedCOL3));
    }

    function rad(uint wad) internal pure returns (uint) {
        return wad * 10 ** 27;
    }

    function deployKeepAuth(address _msgSender) public {
        
        dssDeploy.deployVat();
        dssDeploy.deployDai(99);
        dssDeploy.deployTaxation();
        dssDeploy.deployAuctions(address(gov));
        dssDeploy.deployLiquidator();
        dssDeploy.deployEnd();
        // @TODO set pauseDelay to non-zero?
        dssDeploy.deployPause(0, address(authority));

        // @TODO set config for production?
        dssDeploy.deployESM(address(gov), 10);

        vat = dssDeploy.vat();
        jug = dssDeploy.jug();
        vow = dssDeploy.vow();
        cat = dssDeploy.cat();
        dog = dssDeploy.dog();
        flap = dssDeploy.flap();
        flop = dssDeploy.flop();
        dai = dssDeploy.dai();
        daiJoin = dssDeploy.daiJoin();
        spotter = dssDeploy.spotter();
        pot = dssDeploy.pot();
        cure = dssDeploy.cure();
        end = dssDeploy.end();
        esm = dssDeploy.esm();
        proxyActions = new ProxyActions(address(dssDeploy.pause()), address(new GovActions()));

        /// OnChain Log
        clog = new ChainLog();
        {
            clog.setAddress("MCD_VAT", address(vat));
            clog.setAddress("MCD_JUG", address(jug));
            clog.setAddress("MCD_VOW", address(vow));
            clog.setAddress("MCD_CAT", address(cat));
            clog.setAddress("MCD_DOG", address(dog));
            clog.setAddress("MCD_FLAP", address(flap));
            clog.setAddress("MCD_FLOP", address(flop));
            clog.setAddress("MCD_DAI", address(dai));
            clog.setAddress("MCD_DAIJOIN", address(daiJoin));
            clog.setAddress("MCD_SPOTTER", address(spotter));
            clog.setAddress("MCD_POT", address(pot));
            clog.setAddress("MCD_CURE", address(cure));
            clog.setAddress("MCD_END", address(end));
            clog.setAddress("MCD_ESM", address(esm));
            clog.setIPFS("");
        }

        authority.permit(
            address(proxyActions),
            address(dssDeploy.pause()),
            bytes4(keccak256("plot(address,bytes32,bytes,uint256)"))
        );

        // TODO
        // weth = IERC20(MAINNET_WETH_ADDRESS);
        weth = IERC20(address(new WETH()));
        ethJoin = new GemJoin(address(vat), "ETH", address(weth));
        dssDeploy.deployCollateralFlip("ETH", address(ethJoin), address(pipETH));

        // TODO
        // usdt = IERC20(MAINNET_USDT_ADDRESS);
        usdt = IERC20(address(new TestUSDT()));
        usdtJoin = new GemJoin(address(vat), "USDT-A", address(usdt));
        LinearDecrease calc = calcFab.newLinearDecrease(msg.sender);
        calc.file(bytes32("tau"), 1 hours);
        dssDeploy.deployCollateralClip("USDT-A", address(usdtJoin), address(pipUSDT), address(calc));

        // Set Params
        proxyActions.file(address(vat), bytes32("Line"), uint(10000 * 10 ** 45));
        proxyActions.file(address(vat), bytes32("ETH"), bytes32("line"), uint(10000 * 10 ** 45));
        proxyActions.file(address(vat), bytes32("USDT-A"), bytes32("line"), uint(10000 * 10 ** 45));

        // @TODO is poke setting the price of the asset (ETH or USDT) relative to the generated stablecoin (PHT)
        // or relative to the USD price?
        // @TODO there is no oracle for the GOV token?
        pipETH.poke(bytes32(uint(300 * 10 ** 18))); // Price 300 DAI = 1 ETH (precision 18)
        pipUSDT.poke(bytes32(uint(30 * 10 ** 18))); // Price 30 DAI = 1 USDT (precision 18)

        console.log("after pipUSDT poke");

        // @TODO add / change to ethClip
        (ethFlip, , ) = dssDeploy.ilks("ETH");
        (, usdtClip, ) = dssDeploy.ilks("USDT-A");

        proxyActions.file(address(spotter), "ETH", "mat", uint(1500000000 ether)); // Liquidation ratio 150%
        proxyActions.file(address(spotter), "USDT-A", "mat", uint(1500000000 ether)); // Liquidation ratio 150%

        spotter.poke("ETH");
        spotter.poke("USDT-A");
        console.log("after poke");

        (, , uint spot, , ) = vat.ilks("ETH");
        assertEq(spot, (300 * RAY * RAY) / 1500000000 ether);
        (, , spot, , ) = vat.ilks("USDT-A");
        assertEq(spot, (30 * RAY * RAY) / 1500000000 ether);

        console.log("flop", address(flop));
        console.log("flap", address(flap));

        {
            MockGuard(address(gov.authority())).permit(
                address(flop),
                address(gov),
                bytes4(keccak256("mint(address,uint256)"))
            );
            MockGuard(address(gov.authority())).permit(
                address(flap),
                address(gov),
                bytes4(keccak256("burn(address,uint256)"))
            );
        }

        gov.mint(100 ether);
    }

    function testAuth() public {
        // vat
        assertEq(vat.wards(address(dssDeploy)), 1, "dssDeploy wards");
        assertEq(vat.wards(address(ethJoin)), 1, "ethJoin wards");
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

        // flips
        assertEq(ethFlip.wards(address(dssDeploy)), 1);
        assertEq(ethFlip.wards(address(end)), 1);
        assertEq(ethFlip.wards(address(dssDeploy.pause().proxy())), 1);
        assertEq(ethFlip.wards(address(esm)), 1);

        // clips
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

    function testReleasedAuth() public {
        assertEq(vat.wards(address(dssDeploy)), 0);
        assertEq(cat.wards(address(dssDeploy)), 0);
        assertEq(dog.wards(address(dssDeploy)), 0);
        assertEq(vow.wards(address(dssDeploy)), 0);
        assertEq(jug.wards(address(dssDeploy)), 0);
        assertEq(pot.wards(address(dssDeploy)), 0);
        assertEq(dai.wards(address(dssDeploy)), 0);
        assertEq(spotter.wards(address(dssDeploy)), 0);
        assertEq(flap.wards(address(dssDeploy)), 0);
        assertEq(flop.wards(address(dssDeploy)), 0);
        assertEq(cure.wards(address(dssDeploy)), 0);
        assertEq(end.wards(address(dssDeploy)), 0);
        assertEq(ethFlip.wards(address(dssDeploy)), 0);
        assertEq(usdtClip.wards(address(dssDeploy)), 0);
    }
}
