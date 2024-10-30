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

import "./DssDeploy.sol";
import {GovActions} from "./govActions.sol";

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
contract TestUSDT is ERC20 {
    constructor(uint256 initialSupply) public ERC20("Test USDT", "tstUSDT") {
        _mint(msg.sender, initialSupply);
    }
    function decimals() public view virtual override returns (uint8) {
        return 6;
    }
}

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
    DSValue pipXINF;

    MockGuard authority;

    WETH weth;
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
    TestUSDT usdt;
    GemJoin usdtJoin;
    DaiJoin daiJoin;
    Spotter spotter;
    Pot pot;
    Cure cure;
    End end;
    ESM esm;

    Clipper ethClip;
    Flipper ethFlip;
    Clipper usdtClip;
    DSToken col;
    DSToken col2;
    Flipper colFlip;
    Clipper col2Clip;

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
        authority = new MockGuard();

        user1 = new FakeUser();
        user2 = new FakeUser();

        // hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        // hevm.warp(0);
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

        usdt = new TestUSDT(INITIAL_USDT_SUPPLY);
        usdtJoin = new GemJoin(address(vat), "USDT-A", address(usdt));
        LinearDecrease calc = calcFab.newLinearDecrease(address(this));
        calc.file(bytes32("tau"), 1 hours);
        dssDeploy.deployCollateralClip("USDT-A", address(usdtJoin), address(pipUSDT), address(calc));

        // Set Params
        this.file(address(vat), bytes32("Line"), uint(10000 * 10 ** 45));
        this.file(address(vat), bytes32("ETH"), bytes32("line"), uint(10000 * 10 ** 45));
        this.file(address(vat), bytes32("USDT-A"), bytes32("line"), uint(10000 * 10 ** 45));

        // @TODO is poke setting the price of the asset (ETH or USDT) relative to the generated stablecoin (PHT)
        // or relative to the USD price?
        // @TODO there is no oracle for the GOV token?
        pipETH.poke(bytes32(uint(300 * 10 ** 18))); // Price 300 PHT = 1 ETH (precision 18)
        pipUSDT.poke(bytes32(uint(50 * 10 ** 18))); // Price 50 PHT = 1 USDT (precision 18)
        (, ethClip, ) = dssDeploy.ilks("ETH");
        (ethFlip, , ) = dssDeploy.ilks("ETH");
        (, usdtClip, ) = dssDeploy.ilks("USDT-A");
        this.file(address(spotter), "ETH", "mat", uint(1500000000 ether)); // Liquidation ratio 150%
        this.file(address(spotter), "USDT-A", "mat", uint(1100000000 ether)); // Liquidation ratio 110%
        spotter.poke("ETH");
        spotter.poke("USDT-A");
        (, , uint spot, , ) = vat.ilks("ETH");
        assertEq(spot, (300 * RAY * RAY) / 1500000000 ether);
        (, , spot, , ) = vat.ilks("USDT-A");
        assertEq(spot, (50 * RAY * RAY) / 1100000000 ether);

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
