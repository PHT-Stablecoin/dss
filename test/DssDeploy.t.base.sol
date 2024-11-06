pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "forge-std/Script.sol";
import "forge-std/Test.sol";
import "forge-std/console.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {DSAuth, DSAuthority} from "ds-auth/auth.sol";
import {DSTest} from "ds-test/test.sol";
import {DSToken} from "ds-token/token.sol";
import {DSValue} from "ds-value/value.sol";
import {GemJoin} from "dss/join.sol";
import {LinearDecrease} from "dss/abaci.sol";

import "./helpers/DssDeploy.sol";
import {GovActions} from "./helpers/govActions.sol";

// Chainlink
import {MockAggregatorV3} from "./helpers/MockAggregatorV3.sol";
import {ChainlinkPip, AggregatorV3Interface} from "./helpers/ChainlinkPip.sol";

// Test Tokens
// Governance Token (MKR)
contract XINF is ERC20 {
    address public gov;
    constructor(uint256 initialSupply) public ERC20("Infinex Token", "XINF") {
        _mint(msg.sender, initialSupply);
    }

    function setGov(address _gov) external {
        require(msg.sender == gov || gov == address(0), "XINF/not-authorized");
        gov = _gov;
    }
}

// Collateral Token (USDT)
contract TestUSDT is DSToken {
    constructor() public DSToken("tstUSDT") {
        decimals = 6;
        name = "Test USDT";
    }
}
// contract TestUSDT is ERC20 {
//     constructor(uint256 initialSupply) public ERC20("Test USDT", "tstUSDT") {
//         _mint(msg.sender, initialSupply);
//     }
//     function decimals() public view virtual override returns (uint8) {
//         return 6;
//     }
//     function mint(uint256 amount) public {
//         _mint(msg.sender, amount);
//     }
// }

interface Hevm {
    function warp(uint256) external;
}

interface FlipperLike {
    function tend(uint, uint, uint) external;
    function dent(uint, uint, uint) external;
    function deal(uint) external;
}

interface ClipperLike {
    function take(uint, uint, uint, address, bytes calldata) external;
}

interface HopeLike {
    function hope(address guy) external;
}

contract WETH is DSToken("WETH") {}

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

contract ProxyActions {
    DSPause pause;
    GovActions govActions;

    function rely(address from, address to) external {
        address usr = address(govActions);
        bytes32 tag;
        assembly {
            tag := extcodehash(usr)
        }
        bytes memory fax = abi.encodeWithSignature("rely(address,address)", from, to);
        uint eta = now;

        pause.plot(usr, tag, fax, eta);
        pause.exec(usr, tag, fax, eta);
    }

    function deny(address from, address to) external {
        address usr = address(govActions);
        bytes32 tag;
        assembly {
            tag := extcodehash(usr)
        }
        bytes memory fax = abi.encodeWithSignature("deny(address,address)", from, to);
        uint eta = now;

        pause.plot(usr, tag, fax, eta);
        pause.exec(usr, tag, fax, eta);
    }

    function file(address who, bytes32 what, uint256 data) external {
        address usr = address(govActions);
        bytes32 tag;
        assembly {
            tag := extcodehash(usr)
        }
        bytes memory fax = abi.encodeWithSignature("file(address,bytes32,uint256)", who, what, data);
        uint eta = now;

        pause.plot(usr, tag, fax, eta);
        pause.exec(usr, tag, fax, eta);
    }

    function file(address who, bytes32 ilk, bytes32 what, uint256 data) external {
        address usr = address(govActions);
        bytes32 tag;
        assembly {
            tag := extcodehash(usr)
        }
        bytes memory fax = abi.encodeWithSignature("file(address,bytes32,bytes32,uint256)", who, ilk, what, data);
        uint eta = now;

        pause.plot(usr, tag, fax, eta);
        pause.exec(usr, tag, fax, eta);
    }

    function dripAndFile(address who, bytes32 what, uint256 data) external {
        address usr = address(govActions);
        bytes32 tag;
        assembly {
            tag := extcodehash(usr)
        }
        bytes memory fax = abi.encodeWithSignature("dripAndFile(address,bytes32,uint256)", who, what, data);
        uint eta = now;

        pause.plot(usr, tag, fax, eta);
        pause.exec(usr, tag, fax, eta);
    }

    function dripAndFile(address who, bytes32 ilk, bytes32 what, uint256 data) external {
        address usr = address(govActions);
        bytes32 tag;
        assembly {
            tag := extcodehash(usr)
        }
        bytes memory fax = abi.encodeWithSignature(
            "dripAndFile(address,bytes32,bytes32,uint256)",
            who,
            ilk,
            what,
            data
        );
        uint eta = now;

        pause.plot(usr, tag, fax, eta);
        pause.exec(usr, tag, fax, eta);
    }

    function cage(address end) external {
        address usr = address(govActions);
        bytes32 tag;
        assembly {
            tag := extcodehash(usr)
        }
        bytes memory fax = abi.encodeWithSignature("cage(address)", end);
        uint eta = now;

        pause.plot(usr, tag, fax, eta);
        pause.exec(usr, tag, fax, eta);
    }

    function setAuthority(address newAuthority) external {
        address usr = address(govActions);
        bytes32 tag;
        assembly {
            tag := extcodehash(usr)
        }
        bytes memory fax = abi.encodeWithSignature("setAuthority(address,address)", pause, newAuthority);
        uint eta = now;

        pause.plot(usr, tag, fax, eta);
        pause.exec(usr, tag, fax, eta);
    }

    function setDelay(uint newDelay) external {
        address usr = address(govActions);
        bytes32 tag;
        assembly {
            tag := extcodehash(usr)
        }
        bytes memory fax = abi.encodeWithSignature("setDelay(address,uint256)", pause, newDelay);
        uint eta = now;

        pause.plot(usr, tag, fax, eta);
        pause.exec(usr, tag, fax, eta);
    }

    function setAuthorityAndDelay(address newAuthority, uint newDelay) external {
        address usr = address(govActions);
        bytes32 tag;
        assembly {
            tag := extcodehash(usr)
        }
        bytes memory fax = abi.encodeWithSignature(
            "setAuthorityAndDelay(address,address,uint256)",
            pause,
            newAuthority,
            newDelay
        );
        uint eta = now;

        pause.plot(usr, tag, fax, eta);
        pause.exec(usr, tag, fax, eta);
    }
}

contract MockGuard {
    mapping(address => mapping(address => mapping(bytes4 => bool))) acl;

    function canCall(address src, address dst, bytes4 sig) public view returns (bool) {
        return acl[src][dst][sig];
    }

    function permit(address src, address dst, bytes4 sig) public {
        acl[src][dst][sig] = true;
    }
}

contract DssDeployTestBase is Test, ProxyActions {
    Hevm hevm;

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

    DSToken gov;
    DSValue pipETH;
    DSValue pipCOL;
    DSValue pipCOL2;
    DSValue pipUSDT;
    DSValue pipPHS;
    DSValue pipXINF;
    
    ChainlinkPip pipCOL3;
    MockAggregatorV3 feedCOL3;

    MockGuard authority;

    WETH weth;
    GemJoin ethJoin;
    GemJoin colJoin;
    GemJoin col2Join;
    GemJoin col3Join;

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

    TestUSDT usdt;
    DSToken col;
    DSToken col2;
    DSToken col3;

    Flipper colFlip;
    Clipper col2Clip;
    Clipper col3Clip;

    FakeUser user1;
    FakeUser user2;

    // --- Math ---
    uint256 constant WAD = 10 ** 18;
    uint256 constant RAY = 10 ** 27;
    uint256 constant RAD = 10 ** 45;

    // Governance Parameters
    uint256 constant INITIAL_XINF_SUPPLY = 1000000 * WAD;
    uint256 constant INITIAL_USDT_SUPPLY = 10000000 * (10 ** 6); // USDT has 6 decimals

    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x);
    }

    function deploy() public {
        setUp();
        deployKeepAuth();
        dssDeploy.releaseAuth(address(this));
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
        govActions = new GovActions();

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
        gov.setAuthority(DSAuthority(address(new MockGuard())));
        pipETH = new DSValue();
        pipUSDT = new DSValue();
        pipXINF = new DSValue();
        pipCOL = new DSValue();
        pipCOL2 = new DSValue();

        feedCOL3 = new MockAggregatorV3();
        pipCOL3 = new ChainlinkPip(address(feedCOL3));

        authority = new MockGuard();
        user1 = new FakeUser();
        user2 = new FakeUser();
    }

    function rad(uint wad) internal pure returns (uint) {
        return wad * 10 ** 27;
    }

    function deployKeepAuth() public {
        dssDeploy.deployVat();
        dssDeploy.deployDai(99);
        dssDeploy.deployTaxation();
        dssDeploy.deployAuctions(address(gov));
        dssDeploy.deployLiquidator();
        dssDeploy.deployEnd();
        dssDeploy.deployPause(0, address(authority));
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
        pause = dssDeploy.pause();
        authority.permit(address(this), address(pause), bytes4(keccak256("plot(address,bytes32,bytes,uint256)")));

        weth = new WETH();
        ethJoin = new GemJoin(address(vat), "ETH", address(weth));
        dssDeploy.deployCollateralFlip("ETH", address(ethJoin), address(pipETH));

        col = new DSToken("COL");
        colJoin = new GemJoin(address(vat), "COL", address(col));
        dssDeploy.deployCollateralFlip("COL", address(colJoin), address(pipCOL));

        col2 = new DSToken("COL2");
        col2Join = new GemJoin(address(vat), "COL2", address(col2));
        LinearDecrease calc = calcFab.newLinearDecrease(address(this));
        calc.file(bytes32("tau"), 1 hours);
        dssDeploy.deployCollateralClip("COL2", address(col2Join), address(pipCOL2), address(calc));

        usdt = new TestUSDT();
        usdtJoin = new GemJoin(address(vat), "USDT-A", address(usdt));
        // LinearDecrease calc = calcFab.newLinearDecrease(address(this));
        calc.file(bytes32("tau"), 1 hours);
        dssDeploy.deployCollateralClip("USDT-A", address(usdtJoin), address(pipUSDT), address(calc));

        col3 = new DSToken("COL3");
        col3Join = new GemJoin(address(vat), "COL3", address(col3));
        // LinearDecrease calc = calcFab.newLinearDecrease(address(this));
        calc.file(bytes32("tau"), 1 hours);
        dssDeploy.deployCollateralClip("COL3", address(col3Join), address(pipCOL3), address(calc));
        
        
        // Set Params
        this.file(address(vat), bytes32("Line"), uint(10000 * 10 ** 45));
        this.file(address(vat), bytes32("ETH"), bytes32("line"), uint(10000 * 10 ** 45));
        this.file(address(vat), bytes32("USDT-A"), bytes32("line"), uint(10000 * 10 ** 45));
        this.file(address(vat), bytes32("COL"), bytes32("line"), uint(10000 * 10 ** 45));
        this.file(address(vat), bytes32("COL2"), bytes32("line"), uint(10000 * 10 ** 45));
        this.file(address(vat), bytes32("COL3"), bytes32("line"), uint(10000 * 10 ** 45));

        // @TODO is poke setting the price of the asset (ETH or USDT) relative to the generated stablecoin (PHT)
        // or relative to the USD price?
        // @TODO there is no oracle for the GOV token?
        pipETH.poke(bytes32(uint(300 * 10 ** 18))); // Price 300 DAI = 1 ETH (precision 18)
        pipUSDT.poke(bytes32(uint(30 * 10 ** 18))); // Price 30 DAI = 1 USDT (precision 18)
        pipCOL.poke(bytes32(uint(45 * 10 ** 18))); // Price 45 DAI = 1 COL (precision 18)
        pipCOL2.poke(bytes32(uint(30 * 10 ** 18))); // Price 30 DAI = 1 COL2 (precision 18)
        
        // COL3
        feedCOL3.file("decimals", uint(6));
        feedCOL3.file("answer", int(30 * 10 ** 6)); // Price 30 DAI = 1 COL3 (precision 6)

        // @TODO add / change to ethClip
        (ethFlip, , ) = dssDeploy.ilks("ETH");
        (colFlip, , ) = dssDeploy.ilks("COL");
        (, usdtClip, ) = dssDeploy.ilks("USDT-A");
        (, col2Clip, ) = dssDeploy.ilks("COL2");
        (, col3Clip, ) = dssDeploy.ilks("COL3");


        this.file(address(spotter), "ETH", "mat", uint(1500000000 ether)); // Liquidation ratio 150%
        this.file(address(spotter), "USDT-A", "mat", uint(1500000000 ether)); // Liquidation ratio 150%
        this.file(address(spotter), "COL", "mat", uint(1100000000 ether)); // Liquidation ratio 110%
        this.file(address(spotter), "COL2", "mat", uint(1500000000 ether)); // Liquidation ratio 150%
        this.file(address(spotter), "COL3", "mat", uint(1500000000 ether)); // Liquidation ratio 150%


        spotter.poke("ETH");
        spotter.poke("USDT-A");
        spotter.poke("COL");
        spotter.poke("COL2");
        spotter.poke("COL3");

        (, , uint spot, , ) = vat.ilks("ETH");
        assertEq(spot, (300 * RAY * RAY) / 1500000000 ether);
        (, , spot, , ) = vat.ilks("USDT-A");
        assertEq(spot, (30 * RAY * RAY) / 1500000000 ether);
        (, , spot, , ) = vat.ilks("COL");
        assertEq(spot, (45 * RAY * RAY) / 1100000000 ether);
        (, , spot, , ) = vat.ilks("COL2");
        assertEq(spot, (30 * RAY * RAY) / 1500000000 ether);
        (, , spot, , ) = vat.ilks("COL3");
        console.log("COL3 spot", spot);
        assertEq(spot, (30 * RAY * RAY) / 1500000000 ether); // we are getting 20000000000000000000000000000 from (30 * RAY * RAY) / 1500000000 ether, but the spot price from chainlink gave us 312500000000000000000000000000000

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

        gov.mint(100 ether);
    }
}
