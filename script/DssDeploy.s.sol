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
import {XINF} from "../test/helpers/XINF.sol";

import {ChainLog} from "../test/helpers/ChainLog.sol";
import {DssPsm} from "dss-psm/psm.sol";
import {IlkRegistry} from "dss-ilk-registry/IlkRegistry.sol";

// Chainlink
import {PriceFeedFactory, PriceFeedAggregator} from "./factory/PriceFeedFactory.sol";
import {PriceJoinFeedFactory, PriceJoinFeedAggregator} from "./factory/PriceJoinFeedFactory.sol";
import {ChainlinkPip, AggregatorV3Interface} from "../test/helpers/ChainlinkPip.sol";

// Autoline
import {DssAutoLine} from "dss-auto-line/DssAutoLine.sol";

// Proxy
import {DssProxyActions} from "dss-proxy-actions/DssProxyActions.sol";
import {DssCdpManager} from "dss-cdp-manager/DssCdpManager.sol";
import {DsrManager} from "dsr-manager/DsrManager.sol";
import {GemJoin5} from "dss-gem-joins/join-5.sol";

import {ConfigurableDSToken} from "./factory/ConfigurableDSToken.sol";

interface GemLike {
    function balanceOf(address) external view returns (uint256);
    function burn(uint256) external;
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

interface GemJoinLike {
    function dec() external returns (uint);
    function gem() external returns (GemLike);
    function join(address, uint) external payable;
    function exit(address, uint) external;
}

interface PipLike {
    function peek() external returns (bytes32, bool);
}

contract DssDeployExt is DssDeploy {

    struct TokenParams {
        address token; // optional
        uint8 decimals; // >=18 Decimals only
        uint256 maxSupply; // maxSupply = 0 => unlimited supply
        string name;
        string symbol;
    }

    struct FeedParams {
        address feed; // (optional)
        int initialPrice; // (optional) feed price
        uint8 decimals; // Default: (6 decimals)
        address numeratorFeed; // (optional)
        bool invertNumerator;
        address denominatorFeed;
        bool invertDenominator;
        string feedDescription;
    }

    struct AdapterFeedParams {
        address numeratorFeed; // (optional)
        bool invertNumerator;
        address denominatorFeed;
        bool invertDenominator;
    }

    struct IlkParams {
        bytes32 ilk;
        uint256 line; // Ilk Debt ceiling [RAD]
        uint256 dust; // Ilk Urn Debt floor [RAD]
        uint256 tau; // Default: 1 hours
        uint256 mat; // Liquidation Ratio [RAY]
        uint256 hole; // Gem-limit [RAD]
        uint256 chop; // Liquidation-penalty [WAD]
        uint256 buf; // Initial Auction Increase [RAY]
        uint256 duty; // Jug: ilk fee [RAY]
    }

    address internal ext;

    function setExt(address _ext) public auth {
        ext = _ext;
    }
    
    function addCollateral(
        ProxyActions proxyActions,
        IlkRegistry ilkRegistry,
        IlkParams memory ilkParams,
        TokenParams memory tokenParams,
        FeedParams memory feedParams
    ) public auth returns (GemJoinLike _join, PriceFeedAggregator _feed, address _token, ChainlinkPip _pip) {
        (bool r, bytes memory data) = ext.delegatecall(msg.data);
        return abi.decode(data, (GemJoinLike, PriceFeedAggregator, address, ChainlinkPip));
    }

    function addCollateral(
        ProxyActions proxyActions,
        IlkRegistry ilkRegistry,
        IlkParams memory ilkParams,
        TokenParams memory tokenParams,
        AdapterFeedParams memory adapterFeedParams
    ) public auth returns (GemJoinLike _join, PriceJoinFeedAggregator _feed, address _token, ChainlinkPip _pip) {
        (bool r, bytes memory data) = ext.delegatecall(msg.data);
        return abi.decode(data, (GemJoinLike, PriceJoinFeedAggregator, address, ChainlinkPip));
    }
}

contract DssDeployUtil {

    struct TokenParams {
        address token; // optional
        uint8 decimals; // >=18 Decimals only
        uint256 maxSupply; // maxSupply = 0 => unlimited supply
        string name;
        string symbol;
    }

    struct FeedParams {
        address feed; // (optional)
        int initialPrice; // (optional) feed price
        uint8 decimals; // Default: (6 decimals)
        address numeratorFeed; // (optional)
        bool invertNumerator;
        address denominatorFeed;
        bool invertDenominator;
        string feedDescription;
    }

    struct IlkParams {
        bytes32 ilk;
        uint256 line; // Ilk Debt ceiling [RAD]
        uint256 dust; // Ilk Urn Debt floor [RAD]
        uint256 tau; // Default: 1 hours
        uint256 mat; // Liquidation Ratio [RAY]
        uint256 hole; // Gem-limit [RAD]
        uint256 chop; // Liquidation-penalty [WAD]
        uint256 buf; // Initial Auction Increase [RAY]
        uint256 duty; // Jug: ilk fee [RAY]
    }

    PriceFeedFactory public feedFactory;
    PriceJoinFeedFactory public joinFeedFactory;

    constructor(
        PriceFeedFactory _feedFactory,
        PriceJoinFeedFactory _joinFeedFactory
    ) public {
        joinFeedFactory = _joinFeedFactory;
        feedFactory = _feedFactory;
    }

    function addCollateral(
        ProxyActions proxyActions,
        IlkRegistry ilkRegistry,
        IlkParams memory ilkParams,
        TokenParams memory tokenParams,
        FeedParams memory feedParams
    ) public returns (GemJoinLike _join, AggregatorV3Interface _feed, address _token, ChainlinkPip _pip) {
        require(tokenParams.decimals <= 18, "token-factory-max-decimals");
        require(ilkRegistry.wards(address(this)) == 1, "dss-deploy-ext-ilkreg-not-authorized");

        DssDeploy dssDeploy = DssDeploy(address(this));
        address owner = dssDeploy.owner();

        _token = tokenParams.token;
        if (_token == address(0)) {
            ConfigurableDSToken newToken = new ConfigurableDSToken(
                tokenParams.symbol,
                tokenParams.name,
                tokenParams.decimals, 
                tokenParams.maxSupply);
            newToken.setOwner(owner);
            _token = address(newToken);
        }

        _feed = AggregatorV3Interface(feedParams.feed);
        if (address(_feed) == address(0)) {
            if ( feedParams.numeratorFeed != address(0)) {
                (PriceJoinFeedAggregator feed, ChainlinkPip _pip) = joinFeedFactory.create(
                    feedParams.numeratorFeed,
                    feedParams.denominatorFeed,
                    feedParams.invertNumerator,
                    feedParams.invertDenominator,
                    feedParams.feedDescription
                );
                feed.setOwner(owner);
                _feed = AggregatorV3Interface(address(feed));
            } else {
                (PriceFeedAggregator feed, ChainlinkPip _pip) = feedFactory.create(
                    feedParams.decimals,
                    feedParams.initialPrice,
                    ""
                );
                feed.setOwner(owner);
                _feed = AggregatorV3Interface(address(feed));
            }
        } else {
            _pip = new ChainlinkPip(address(_feed));
        }

        
        if (tokenParams.decimals <= 6) {
            _join = GemJoinLike(address(new GemJoin5(address(dssDeploy.vat()), ilkParams.ilk, _token)));
        } else {
            _join = GemJoinLike(address(new GemJoin(address(dssDeploy.vat()), ilkParams.ilk, _token)));
        }

        {
            LinearDecrease _calc = dssDeploy.calcFab().newLinearDecrease(address(this));
            _calc.file(bytes32("tau"), ilkParams.tau);
            _calc.rely(owner);
            _calc.deny(address(this));
            dssDeploy.deployCollateralClip(ilkParams.ilk, address(_join), address(_pip), address(_calc));
        }

        {
            proxyActions.file(address(dssDeploy.vat()), ilkParams.ilk, bytes32("line"), ilkParams.line);
            proxyActions.file(address(dssDeploy.vat()), ilkParams.ilk, bytes32("dust"), ilkParams.dust);
            proxyActions.file(address(dssDeploy.spotter()), ilkParams.ilk, bytes32("mat"), ilkParams.mat);
        }


        {
            dssDeploy.dog().file(ilkParams.ilk, "hole", ilkParams.hole); // Set PHP-A limit to 5 million DAI (RAD units)
            dssDeploy.dog().file("Hole", ilkParams.hole + dssDeploy.dog().Hole()); // Increase global limit
            dssDeploy.dog().file(ilkParams.ilk, "chop", ilkParams.chop); // Set the liquidation penalty (chop) for "PHP-A" to 13% (1.13e18 in WAD units)
        }

        {
            (, Clipper clip, ) = dssDeploy.ilks(ilkParams.ilk);
            clip.file("buf", ilkParams.buf); // Set a 20% increase in auctions (RAY)
        }
        
        {
            // Set Ilk Fees
            dssDeploy.jug().file(ilkParams.ilk, "duty", ilkParams.duty); // 6% duty fee;
            dssDeploy.jug().drip(ilkParams.ilk);
        }

        ilkRegistry.add(address(_join));
        dssDeploy.spotter().poke(ilkParams.ilk);
    }
}

contract DssDeployScript is Script, Test {
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

    DssDeployExt dssDeploy;
    ProxyActions proxyActions;
    DssProxyActions dssProxyActions;
    DssCdpManager dssCdpManager;
    DsrManager dsrManager;

    DSToken gov;
    ChainlinkPip pipPHP;
    ChainlinkPip pipUSDT;

    PriceFeedAggregator feedPHP;
    PriceFeedAggregator feedUSDT;

    MockGuard authority;

    DSToken usdt;
    DSToken php;

    GemJoin5 phpJoin;
    GemJoin ethJoin;
    GemJoin5 usdtJoin;

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

    function run() public {
        vm.startBroadcast();

        setUp();
        deployKeepAuth(address(dssDeploy));
        testAuth();

        // TODO: Release Auth
        // dssDeploy.releaseAuth(address(dssDeploy));
        // dssDeploy.releaseAuthFlip("ETH", address(dssDeploy));
        // dssDeploy.releaseAuthClip("PHP-A", address(dssDeploy));
        // dssDeploy.releaseAuthClip("USDT-A", address(dssDeploy));
        // testReleasedAuth();

        // ChainLog
        {
            clog = new ChainLog();
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

            // Custom
            clog.setAddress("MCD_PSM", address(psm));
            clog.setAddress("MCD_ILKS", address(ilkRegistry));
            clog.setAddress("MCD_PROXY_ACTIONS", address(proxyActions));
            clog.setAddress("MCD_DSS_PROXY_ACTIONS", address(dssProxyActions));
            clog.setAddress("MCD_DSS_PROXY_CDP_MANAGER", address(dssCdpManager));
            clog.setAddress("MCD_PROXY_DSR_MANAGER", address(dsrManager));

            clog.setIPFS("");
        }

        // artifacts
        {
            string memory root = vm.projectRoot();
            string memory path = string(
                abi.encodePacked(root, "/script/output/", vm.toString(chainId()), "/dssDeploy.artifacts.json")
            );

            string memory artifacts = "artifacts";
            artifacts.serialize("clog", address(clog));

            artifacts.serialize("vat", address(vat));
            artifacts.serialize("jug", address(jug));
            artifacts.serialize("vow", address(vow));
            artifacts.serialize("cat", address(cat));
            artifacts.serialize("dog", address(dog));
            artifacts.serialize("flap", address(flap));
            artifacts.serialize("flop", address(flop));
            artifacts.serialize("dai", address(dai));
            artifacts.serialize("daiJoin", address(daiJoin));
            artifacts.serialize("spotter", address(spotter));
            artifacts.serialize("pot", address(pot));
            artifacts.serialize("cure", address(cure));
            artifacts.serialize("end", address(end));
            artifacts.serialize("esm", address(esm));

            artifacts.serialize("pipPHP", address(pipPHP));
            artifacts.serialize("pipUSDT", address(pipUSDT));
            artifacts.serialize("feedPHP", address(feedPHP));
            artifacts.serialize("feedUSDT", address(feedUSDT));

            artifacts.serialize("phpClip", address(phpClip));
            artifacts.serialize("usdtClip", address(usdtClip));

            artifacts.serialize("authority", address(authority));
            artifacts.serialize("psm", address(psm));
            artifacts.serialize("autoline", address(autoline));
            artifacts.serialize("ilkRegistry", address(ilkRegistry));
            artifacts.serialize("proxyActions", address(proxyActions));
            artifacts.serialize("dssProxyActions", address(dssProxyActions));
            artifacts.serialize("dssCdpManager", address(dssCdpManager));
            artifacts.serialize("dsrManager", address(dsrManager));

            string memory json = artifacts.serialize("dssDeploy", address(dssDeploy));
            json.write(path);
        }

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


        dssDeploy = new DssDeployExt();
        dssDeploy.setExt(address(new DssDeployUtil(
            new PriceFeedFactory(),
            new PriceJoinFeedFactory()
        )));

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

        // todo: replace this with collateral type factory for tests
        feedUSDT = new PriceFeedAggregator();
        feedPHP = new PriceFeedAggregator();

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
        dsrManager = new DsrManager(address(pot), address(daiJoin));

        authority.permit(
            address(proxyActions),
            address(dssDeploy.pause()),
            bytes4(keccak256("plot(address,bytes32,bytes,uint256)"))
        );

        // Token Factory
        usdt = DSToken(address(new ConfigurableDSToken("tstUSDT", "Test USDT", 6, 0))); // maxSupply = 0 => unlimited supply
        // usdt = new TestUSDT();
        usdtJoin = new GemJoin5(address(vat), "USDT-A", address(usdt));
        LinearDecrease calcUSDT = calcFab.newLinearDecrease(msg.sender);
        calcUSDT.file(bytes32("tau"), 1 hours);
        dssDeploy.deployCollateralClip("USDT-A", address(usdtJoin), address(pipUSDT), address(calcUSDT));

        // Token Factory
        php = DSToken(address(new ConfigurableDSToken("tstPHP", "Test PHP", 6, 0)));
        // php = new TestPHP();
        phpJoin = new GemJoin5(address(vat), "PHP-A", address(php));
        LinearDecrease calcPHP = calcFab.newLinearDecrease(msg.sender);
        calcPHP.file(bytes32("tau"), 1 hours);
        dssDeploy.deployCollateralClip("PHP-A", address(phpJoin), address(pipPHP), address(calcPHP));

        // Set Params for debt ceiling
        proxyActions.file(address(vat), bytes32("Line"), uint(10_000_000 * 10 ** 45)); // 10M PHT
        proxyActions.file(address(vat), bytes32("PHP-A"), bytes32("line"), uint(5_000_000 * 10 ** 45)); // 5M
        proxyActions.file(address(vat), bytes32("USDT-A"), bytes32("line"), uint(5_000_000 * 10 ** 45)); // 5M

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

        proxyActions.file(address(spotter), "PHP-A", "mat", uint(1050000000 ether)); // Liquidation ratio 105%
        proxyActions.file(address(spotter), "USDT-A", "mat", uint(1050000000 ether)); // Liquidation ratio 105%

        spotter.poke("PHP-A");
        spotter.poke("USDT-A");

        // TODO: SETUP GemJoinX (usdtJoin is incorrect)
        // psm = new DssPsm(address(usdtJoin), address(daiJoin), address(vow));

        ilkRegistry = new IlkRegistry(address(vat), address(dog), address(cat), address(spotter));
        ilkRegistry.add(address(phpJoin));
        ilkRegistry.add(address(usdtJoin));
        ilkRegistry.rely(address(dssDeploy));

        (, , uint spot, , ) = vat.ilks("PHP-A");
        assertEq(spot, (1 * RAY * RAY) / 1050000000 ether);
        (, , spot, , ) = vat.ilks("USDT-A");
        assertEq(spot, (58 * RAY * RAY) / 1050000000 ether);

        {
            // Set Liquidation/Auction Rules (Dog)
            proxyActions.file(address(dog), "Hole", 10_000_000 * RAD); // Set global limit to 10 million DAI (RAD units)

            proxyActions.file(address(dog), "PHP-A", "hole", 5_000_000 * RAD); // Set PHP-A limit to 5 million DAI (RAD units)
            proxyActions.file(address(dog), "PHP-A", "chop", 1.13e18); // Set the liquidation penalty (chop) for "PHP-A" to 13% (1.13e18 in WAD units)

            proxyActions.file(address(dog), "USDT-A", "hole", 5_000_000 * RAD); // Set USDT-A limit to 5 million DAI (RAD units)
            proxyActions.file(address(dog), "USDT-A", "chop", 1.13e18); // Set the liquidation penalty (chop) for "USDT-A" to 13% (1.13e18 in WAD units)
        }

        {
            // Set Ilk Fees
            proxyActions.file(address(jug), "base", 1.02e27); // 2% base global fee 
            proxyActions.file(address(jug),"USDT-A","duty", 1.06e27); // 6% duty fee;
            proxyActions.file(address(jug),"PHP-A","duty", 1.06e27); // 6% duty fee;
            
            /// Run initial drip
            jug.drip("USDT-A");
            jug.drip("PHP-A");
        }

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
        assertEq(phpClip.wards(address(dssDeploy)), 0);
        assertEq(usdtClip.wards(address(dssDeploy)), 0);
    }
}
