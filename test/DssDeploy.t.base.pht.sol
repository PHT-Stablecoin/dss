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

// Chainlink
import {PriceFeedFactory, PriceFeedAggregator} from "../script/factory/PriceFeedFactory.sol";
import {PriceJoinFeedFactory, PriceJoinFeedAggregator} from "../script/factory/PriceJoinFeedFactory.sol";
import {ChainlinkPip, AggregatorV3Interface} from "../test/helpers/ChainlinkPip.sol";

// Autoline
import {DssAutoLine} from "dss-auto-line/DssAutoLine.sol";

// Proxy
import {DssProxyActions} from "dss-proxy-actions/DssProxyActions.sol";
import {DssCdpManager} from "dss-cdp-manager/DssCdpManager.sol";
import {DsrManager} from "dsr-manager/DsrManager.sol";
import {GemJoin5} from "dss-gem-joins/join-5.sol";

import {ConfigurableDSToken} from "../script/factory/ConfigurableDSToken.sol";

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
        PriceFeedFactory factory;
        PriceJoinFeedFactory joinFactory;
        address feed; // (optional)
        int initialPrice; // (optional) feed price
        uint8 decimals; // Default: (6 decimals)
        address numeratorFeed; // (optional)
        address denominatorFeed;
        bool invertNumerator;
        bool invertDenominator;
        string feedDescription;
    }

    struct AdapterFeedParams {
        PriceJoinFeedFactory factory;
        address numeratorFeed; // (optional)
        address denominatorFeed;
        bool invertNumerator;
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
        PriceFeedFactory factory;
        PriceJoinFeedFactory joinFactory;
        address feed; // (optional)
        int initialPrice; // (optional) feed price
        uint8 decimals; // Default: (6 decimals)
        address numeratorFeed; // (optional)
        address denominatorFeed;
        bool invertNumerator;
        bool invertDenominator;
        string feedDescription;
    }

    struct AdapterFeedParams {
        PriceJoinFeedFactory factory;
        address numeratorFeed; // (optional)
        address denominatorFeed;
        bool invertNumerator;
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
                tokenParams.maxSupply
            );
            newToken.setOwner(owner);
            _token = address(newToken);
        }

        _feed = AggregatorV3Interface(feedParams.feed);
        if (address(_feed) == address(0)) {
            if (feedParams.numeratorFeed != address(0)) {
                PriceJoinFeedAggregator feed;
                (feed, _pip) = feedParams.joinFactory.create(
                    feedParams.numeratorFeed,
                    feedParams.denominatorFeed,
                    feedParams.invertNumerator,
                    feedParams.invertDenominator,
                    feedParams.feedDescription
                );
                feed.setOwner(owner);
                _feed = AggregatorV3Interface(address(feed));
            } else {
                PriceFeedAggregator feed;
                (feed, _pip) = feedParams.factory.create(feedParams.decimals, feedParams.initialPrice, "");
                feed.setOwner(owner);
                _feed = AggregatorV3Interface(address(feed));
            }
        } else {
            _pip = new ChainlinkPip(address(_feed));
        }

        if (tokenParams.decimals < 18) {
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

    DssDeployExt dssDeploy;
    DssDeployUtil dssDeployUtil;

    ProxyActions proxyActions;
    DssProxyActions dssProxyActions;
    DssCdpManager dssCdpManager;
    DsrManager dsrManager;

    DSToken gov;
    ChainlinkPip pipPHP;
    ChainlinkPip pipUSDT;

    PriceFeedAggregator feedPHP;
    PriceFeedAggregator feedUSDT;

    PriceFeedFactory feedFactory;
    PriceJoinFeedFactory joinFeedFactory;

    MockGuard authority;

    DSToken usdt;
    DSToken php;

    GemJoinLike phpJoin;
    GemJoin ethJoin;
    GemJoinLike usdtJoin;

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

        dssDeploy = new DssDeployExt();
        dssDeploy.setExt(address(new DssDeployUtil()));

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

        feedFactory = new PriceFeedFactory();
        joinFeedFactory = new PriceJoinFeedFactory();

        authority.permit(
            address(proxyActions),
            address(dssDeploy.pause()),
            bytes4(keccak256("plot(address,bytes32,bytes,uint256)"))
        );

        // SetupIlkRegistry
        ilkRegistry = new IlkRegistry(address(vat), address(dog), address(cat), address(spotter));
        ilkRegistry.rely(address(dssDeploy));

        // usdt = DSToken(address(new ConfigurableDSToken("tstUSDT", "Test USDT", 6, 0))); // maxSupply = 0 => unlimited supply
        address usdtAddr;
        (usdtJoin, feedUSDT, usdtAddr, pipUSDT) = dssDeploy.addCollateral(
            proxyActions,
            ilkRegistry,
            DssDeployExt.IlkParams({
                ilk: "USDT-A",
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
                symbol: "tstUSDT",
                name: "Test USDT",
                decimals: 6,
                maxSupply: 0
            }),
            DssDeployExt.FeedParams({
                factory: feedFactory,
                joinFactory: joinFeedFactory,
                feed: address(0),
                decimals: 6,
                initialPrice: int(58 * 10 ** 6), // Price 58 DAI (PHT) = 1 USDT (precision 6)
                numeratorFeed: address(0),
                invertNumerator: false,
                denominatorFeed: address(0),
                invertDenominator: false,
                feedDescription: ""
            })
        );
        usdt = DSToken(usdtAddr);

        (, usdtClip, ) = dssDeploy.ilks("USDT-A");

        // php = DSToken(address(new ConfigurableDSToken("tstPHP", "Test PHP", 6, 0)));
        address phpAddr;
        (phpJoin, feedPHP, phpAddr, pipPHP) = dssDeploy.addCollateral(
            proxyActions,
            ilkRegistry,
            DssDeployExt.IlkParams({
                ilk: "PHP-A",
                line: uint(10000 * 10 ** 45),
                dust: uint(0),
                tau: 1 hours,
                mat: uint(1500000000 ether), // Liquidation Ratio (150%),
                hole: 5_000_000 * RAD, // Set PHP-A limit to 5 million DAI (RAD units)
                chop: 1.13e18, // Set the liquidation penalty (chop) for "PHP-A" to 13% (1.13e18 in WAD units)
                buf: 1.20e27, // Set a 20% increase in auctions (RAY)
                duty: 1.0000000018477e27 // 0.00000018477% => 6% Annual duty
            }),
            DssDeployExt.TokenParams({
                token: address(0),
                symbol: "tstPHP",
                name: "Test PHP",
                decimals: 6,
                maxSupply: 0
            }),
            DssDeployExt.FeedParams({
                factory: feedFactory,
                joinFactory: joinFeedFactory,
                feed: address(0),
                decimals: 6,
                initialPrice: int(1 * 10 ** 6), // Price 1 DAI (PHT) = 1 PHP (precision 6)
                numeratorFeed: address(0),
                invertNumerator: false,
                denominatorFeed: address(0),
                invertDenominator: false,
                feedDescription: ""
            })
        );
        php = DSToken(phpAddr);
        (, phpClip, ) = dssDeploy.ilks("PHP-A");

        // Set global limit to 10 million DAI (RAD units)
        proxyActions.file(address(dog), "Hole", 10_000_000 * RAD);
        // Set Debt Ceiling (10_000 DAI)
        proxyActions.file(address(vat), bytes32("Line"), uint(10000 * RAD));
        // Set Global Base Fee
        proxyActions.file(address(jug), "base", 0.0000000006279e27); // 0.00000006279% => 2% base global fee

        //TODO: SETUP GemJoinX (usdtJoin is incorrect)
        // psm = new DssPsm(address(usdtJoin), address(daiJoin), address(vow));

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
