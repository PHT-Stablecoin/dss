pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

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

import {GovActions} from "../test/helpers/govActions.sol";

import "../test/helpers/DssDeploy.sol";
import {FakeUser} from "../test/helpers/FakeUser.sol";
import {MockGuard} from "../test/helpers/MockGuard.sol";
import {ProxyActions} from "../test/helpers/ProxyActions.sol";
import {XINF} from "../test/helpers/XINF.sol";

import {ChainLog} from "../test/helpers/ChainLog.sol";
import {DssPsm} from "dss-psm/psm.sol";
import {IlkRegistry} from "dss-ilk-registry/IlkRegistry.sol";

// Chainlink
import {MockAggregatorV3} from "../test/helpers/MockAggregatorV3.sol";
import {ChainlinkPip, AggregatorV3Interface} from "../test/helpers/ChainlinkPip.sol";

// Autoline
import {DssAutoLine} from "dss-auto-line/DssAutoLine.sol";

// Proxy
import {DssProxyActions} from "dss-proxy-actions/DssProxyActions.sol";
import {DssCdpManager} from "dss-cdp-manager/DssCdpManager.sol";

// Collateral Token (USDT)
contract TestUSDT is DSToken {
    constructor() public DSToken("tstUSDT") {
        decimals = 6;
        name = "Test USDT";
    }
}

// Collateral Token (PHP)
contract TestPHP is DSToken {
    constructor() public DSToken("tstPHP") {
        decimals = 6;
        name = "Test PHP";
    }
}

contract DssDeployTestBasePHT is Test {
    using stdJson for string;

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
    DssProxyActions dssProxyActions;
    DssCdpManager dssCdpManager;

    DSToken gov;
    ChainlinkPip pipPHP;
    ChainlinkPip pipUSDT;

    MockAggregatorV3 feedPHP;
    MockAggregatorV3 feedUSDT;

    MockGuard authority;

    TestUSDT usdt;
    TestPHP php;

    GemJoin phpJoin;
    GemJoin ethJoin;
    GemJoin usdtJoin;

    Vat vat;
    Jug jug;
    Vow vow;
    Cat cat;
    Dog dog;
    Flapper flap;
    Flopper flop;
    Dai dai;
    DaiJoin daiJoin;
    Spotter spotter;
    Pot pot;
    Cure cure;
    End end;
    ESM esm;

    Clipper usdtClip;
    Clipper phpClip;

    ChainLog clog;
    DssAutoLine autoline;
    DssPsm psm;
    IlkRegistry ilkRegistry;

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

    // MARKET (2024-Q3)
    uint256 constant PHP_USD_PRICE_E18 = 58_676_224_131_699_110_000; //

    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x);
    }

    function chainId() internal view returns (uint256 _chainId) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            _chainId := chainid()
        }
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
        authority = new MockGuard();

        feedUSDT = new MockAggregatorV3();
        feedPHP = new MockAggregatorV3();

        pipUSDT = new ChainlinkPip(address(feedUSDT));
        pipPHP = new ChainlinkPip(address(feedPHP));
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
        autoline = new DssAutoLine(address(vat));
        dssProxyActions = new DssProxyActions();
        dssCdpManager = new DssCdpManager(address(vat));

        authority.permit(
            address(proxyActions),
            address(dssDeploy.pause()),
            bytes4(keccak256("plot(address,bytes32,bytes,uint256)"))
        );

        usdt = new TestUSDT();
        usdtJoin = new GemJoin(address(vat), "USDT-A", address(usdt));
        LinearDecrease calcUSDT = calcFab.newLinearDecrease(address(this));
        calcUSDT.file(bytes32("tau"), 1 hours);
        dssDeploy.deployCollateralClip("USDT-A", address(usdtJoin), address(pipUSDT), address(calcUSDT));

        php = new TestPHP();
        phpJoin = new GemJoin(address(vat), "PHP-A", address(php));
        LinearDecrease calcPHP = calcFab.newLinearDecrease(address(this));
        calcPHP.file(bytes32("tau"), 1 hours);
        dssDeploy.deployCollateralClip("PHP-A", address(phpJoin), address(pipPHP), address(calcPHP));

        // Set Params
        proxyActions.file(address(vat), bytes32("Line"), uint(10000 * 10 ** 45));
        proxyActions.file(address(vat), bytes32("PHP-A"), bytes32("line"), uint(10000 * 10 ** 45));
        proxyActions.file(address(vat), bytes32("USDT-A"), bytes32("line"), uint(10000 * 10 ** 45));

        // @TODO is poke setting the price of the asset (ETH or USDT) relative to the generated stablecoin (PHT)
        // or relative to the USD price?
        // @TODO there is no oracle for the GOV token?

        feedUSDT.file("decimals", uint(6));
        feedUSDT.file("answer", int(58 * 10 ** 6)); // Price 58 DAI (PHT) = 1 USDT (precision 6)

        feedPHP.file("decimals", uint(6));
        feedPHP.file("answer", int(1 * 10 ** 6)); // Price 1 DAI (PHT) = 1 PHP (precision 6)

        // @TODO add / change to ethClip
        (, phpClip, ) = dssDeploy.ilks("PHP-A");
        (, usdtClip, ) = dssDeploy.ilks("USDT-A");

        proxyActions.file(address(spotter), "PHP-A", "mat", uint(1500000000 ether)); // Liquidation ratio 150%
        proxyActions.file(address(spotter), "USDT-A", "mat", uint(1500000000 ether)); // Liquidation ratio 150%

        spotter.poke("PHP-A");
        spotter.poke("USDT-A");

        //TODO: SETUP GemJoinX (usdtJoin is incorrect)
        // psm = new DssPsm(address(usdtJoin), address(daiJoin), address(vow));

        ilkRegistry = new IlkRegistry(address(vat), address(dog), address(cat), address(spotter));
        ilkRegistry.add(address(phpJoin));
        ilkRegistry.add(address(usdtJoin));

        (, , uint spot, , ) = vat.ilks("PHP-A");
        assertEq(spot, (1 * RAY * RAY) / 1500000000 ether);
        (, , spot, , ) = vat.ilks("USDT-A");
        assertEq(spot, (58 * RAY * RAY) / 1500000000 ether);

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
}
