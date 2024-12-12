pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "forge-std/console.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// import everything that DssDeploy imports
import "lib/dss-cdp-manager/lib/dss-deploy/src/DssDeploy.sol";
import {DSAuth, DSAuthority} from "ds-auth/auth.sol";
import {DSTest} from "ds-test/test.sol";
import {DSToken} from "ds-token/token.sol";
import {DSValue} from "ds-value/value.sol";
import {GemJoin} from "dss/join.sol";
import {LinearDecrease} from "dss/abaci.sol";
import {DssPsm} from "dss-psm/psm.sol";
import {IlkRegistry} from "dss-ilk-registry/IlkRegistry.sol";
import {DssProxyActions} from "dss-proxy-actions/DssProxyActions.sol";
import {DssCdpManager} from "dss-cdp-manager/DssCdpManager.sol";
import {DsrManager} from "dsr-manager/DsrManager.sol";
import {GemJoin5} from "dss-gem-joins/join-5.sol";
import {DssAutoLine} from "dss-auto-line/DssAutoLine.sol";

// --- custom code ---
// import {ChainHelper} from "./helpers/ChainHelper.sol";
import {GovActions} from "../test/helpers/govActions.sol";
import {DSRoles} from "./lib/Roles.sol";
import {FakeUser} from "../test/helpers/FakeUser.sol";
import {MockGuard} from "../test/helpers/MockGuard.sol";
import {ProxyActions} from "../test/helpers/ProxyActions.sol";
import {XINF} from "../test/helpers/XINF.sol";
import {ChainLog} from "../test/helpers/ChainLog.sol";

// Chainlink
import {PriceFeedFactory, PriceFeedAggregator} from "./factory/PriceFeedFactory.sol";
import {PriceJoinFeedFactory, PriceJoinFeedAggregator} from "./factory/PriceJoinFeedFactory.sol";
import {ChainlinkPip, AggregatorV3Interface} from "../test/helpers/ChainlinkPip.sol";
import {ConfigurableDSToken} from "./token/ConfigurableDSToken.sol";
import {PHTDeployConfig} from "./PHTDeployConfig.sol";
interface IThingAdmin {
    // --- Administration ---
    function file(bytes32 what, address data) external;
    function file(bytes32 what, bool data) external;
    function file(bytes32 what, uint data) external;
}

interface RelyLike {
    function rely(address usr) external;
}

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

contract PHTDeploy is DssDeploy {
    address dssProxyRegistry;
    ProxyActions proxyActions;
    DssProxyActions dssProxyActions;
    DssCdpManager dssCdpManager;
    DsrManager dsrManager;

    DSToken gov;
    ChainlinkPip pipPHP;
    ChainlinkPip pipUSDT;

    PriceFeedFactory priceFeedFactory;
    PriceJoinFeedFactory priceJoinFeedFactory;

    address feedPHP;
    address feedUSDT;

    DSToken usdt;
    DSToken php;

    GemJoinLike phpJoin;
    GemJoinLike usdtJoin;

    Clipper usdtClip;
    Clipper phpClip;

    ChainLog clog;
    DssAutoLine autoline;
    DssPsm psm;
    IlkRegistry ilkRegistry;

    // -- ROLES --
    uint8 constant ROLE_GOV_MINT_BURN = 10;
    uint8 constant ROLE_CAN_PLOT = 11;

    // --- Math ---
    uint256 constant WAD = 10 ** 18;
    uint256 constant RAY = 10 ** 27;
    uint256 constant RAD = 10 ** 45;

    address constant MULTISIG = 0x695bc953b80358E54eC5a16AbDB1Aa939Ebb665A;
    address constant TESTER = 0x374334e22B5d6898AF77AC4d907d8b9Aca206605;

    function deploy(PHTDeployConfig memory _c) public {
        deployAuthority();
        deployFabs(_c.govTokenSymbol);
        deployKeepAuth(_c);

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
        // {
        //     string memory root = vm.projectRoot();
        //     string memory path = string(
        //         abi.encodePacked(root, "/script/output/", vm.toString(chainId()), "/dssDeploy.artifacts.json")
        //     );

        //     string memory artifacts = "artifacts";
        //     artifacts.serialize("clog", address(clog));

        //     artifacts.serialize("vat", address(vat));
        //     artifacts.serialize("jug", address(jug));
        //     artifacts.serialize("vow", address(vow));
        //     artifacts.serialize("cat", address(cat));
        //     artifacts.serialize("dog", address(dog));
        //     artifacts.serialize("flap", address(flap));
        //     artifacts.serialize("flop", address(flop));
        //     artifacts.serialize("dai", address(dai));
        //     artifacts.serialize("daiJoin", address(daiJoin));
        //     artifacts.serialize("spotter", address(spotter));
        //     artifacts.serialize("pot", address(pot));
        //     artifacts.serialize("cure", address(cure));
        //     artifacts.serialize("end", address(end));
        //     artifacts.serialize("esm", address(esm));

        //     artifacts.serialize("pipPHP", address(pipPHP));
        //     artifacts.serialize("pipUSDT", address(pipUSDT));
        //     artifacts.serialize("feedPHP", address(feedPHP));
        //     artifacts.serialize("feedUSDT", address(feedUSDT));

        //     artifacts.serialize("phpClip", address(phpClip));
        //     artifacts.serialize("usdtClip", address(usdtClip));

        //     artifacts.serialize("authority", address(authority));
        //     artifacts.serialize("psm", address(psm));
        //     artifacts.serialize("autoline", address(autoline));
        //     artifacts.serialize("ilkRegistry", address(ilkRegistry));
        //     artifacts.serialize("proxyActions", address(proxyActions));
        //     artifacts.serialize("dssProxyActions", address(dssProxyActions));
        //     artifacts.serialize("dssCdpManager", address(dssCdpManager));
        //     artifacts.serialize("dsrManager", address(dsrManager));

        //     artifacts.serialize("priceFeedFactory", address(priceFeedFactory));
        //     artifacts.serialize("priceJoinFeedFactory", address(priceJoinFeedFactory));
        //     artifacts.serialize("dssProxyRegistry", address(dssProxyRegistry));

        //     string memory json = artifacts.serialize("dssDeploy", address(dssDeploy));
        //     json.write(path);
        // }
    }

    function deployAuthority() private {
        // @TODO setOwner
        authority = new DSRoles();
    }

    function deployFabs(string memory _govSymbol) private {
        this.addFabs1(
            new VatFab(),
            new JugFab(),
            new VowFab(),
            new CatFab(),
            new DogFab(),
            new DaiFab(),
            new DaiJoinFab()
        );

        this.addFabs2(
            new FlapFab(),
            new FlopFab(),
            new FlipFab(),
            new ClipFab(),
            new CalcFab(),
            new SpotFab(),
            new PotFab(),
            new CureFab(),
            new EndFab(),
            new ESMFab(),
            new PauseFab()
        );

        gov = new DSToken(_govSymbol);
        gov.setAuthority(authority);
    }

    function deployKeepAuth(PHTDeployConfig memory _c) public {
        this.deployVat();
        this.deployDai(chainId());
        this.deployTaxation();
        this.deployAuctions(address(gov));
        this.deployLiquidator();
        this.deployEnd();
        // @TODO set pauseDelay to non-zero?
        this.deployPause(0, address(authority));

        // @TODO set config for production?
        this.deployESM(address(gov), 10);

        vat = this.vat();
        jug = this.jug();
        vow = this.vow();
        cat = this.cat();
        dog = this.dog();
        flap = this.flap();
        flop = this.flop();
        dai = this.dai();
        daiJoin = this.daiJoin();
        spotter = this.spotter();
        pot = this.pot();
        cure = this.cure();
        end = this.end();
        esm = this.esm();

        // @TODO GovActions
        proxyActions = new ProxyActions(address(this.pause()), address(new GovActions()));

        // dssProxyRegistry = ChainHelper.deployCode("./out_pht/DssProxyRegistry.sol/DssProxyRegistry.json");

        autoline = new DssAutoLine(address(vat));
        dssProxyActions = new DssProxyActions();
        dssCdpManager = new DssCdpManager(address(vat));
        dsrManager = new DsrManager(address(pot), address(daiJoin));

        PriceFeedFactory feedFactory = new PriceFeedFactory();
        PriceJoinFeedFactory joinFeedFactory = new PriceJoinFeedFactory();

        DSRoles(address(authority)).setUserRole(address(proxyActions), ROLE_CAN_PLOT, true);

        DSRoles(address(authority)).setRoleCapability(
            ROLE_CAN_PLOT,
            address(this.pause()),
            bytes4(keccak256("plot(address,bytes32,bytes,uint256)")),
            true
        );

        // SetupIlkRegistry
        ilkRegistry = new IlkRegistry(address(vat), address(dog), address(cat), address(spotter));
        ilkRegistry.rely(address(this));

        // address usdtAddr;
        // (usdtJoin, feedUSDT, usdtAddr, pipUSDT) = dssDeploy.addCollateral(
        //     proxyActions,
        //     ilkRegistry,
        //     PHTDeploy.IlkParams({
        //         ilk: "USDT-A",
        //         line: uint(5_000_000 * RAD), // Set USDT-A limit to 5 million DAI (RAD units)
        //         dust: uint(0),
        //         tau: 1 hours,
        //         mat: uint(1050000000 ether), // mat: Liquidation Ratio (105%),
        //         hole: 5_000_000 * RAD, // Set USDT-A limit to 5 million DAI (RAD units)
        //         chop: 1.13e18, // Set the liquidation penalty (chop) for "USDT-A" to 13% (1.13e18 in WAD units)
        //         buf: 1.20e27, // Set a 20% increase in auctions (RAY)
        //         // duty: 1.0000000018477e27 // 0.00000018477% => 6% Annual duty
        //         duty: 1.0000000012436807e27 // => 4%
        //     }),
        //     PHTDeploy.TokenParams({token: address(0), symbol: "tstUSDT", name: "Test USDT", decimals: 6, maxSupply: 0}),
        //     PHTDeploy.FeedParams({
        //         factory: priceFeedFactory,
        //         joinFactory: priceJoinFeedFactory,
        //         feed: address(0),
        //         decimals: 6,
        //         initialPrice: int(58 * 10 ** 6), // Price 58 DAI (PHT) = 1 USDT (precision 6)
        //         numeratorFeed: address(0),
        //         invertNumerator: false,
        //         denominatorFeed: address(0),
        //         invertDenominator: false,
        //         feedDescription: ""
        //     })
        // );

        // // // Minting of test tokens is for development purposes only
        // usdt = DSToken(usdtAddr);
        // usdt.mint(5_000_000 * 10 ** 6);
        // usdt.mint(MULTISIG, 5_000_000 * 10 ** 6);
        // usdt.mint(TESTER, 5_000_000 * 10 ** 6);

        // (, usdtClip, ) = dssDeploy.ilks("USDT-A");

        // // address phpAddr;
        // (phpJoin, feedPHP, phpAddr, pipPHP) = dssDeploy.addCollateral(
        //     proxyActions,
        //     ilkRegistry,
        //     PHTDeploy.IlkParams({
        //         ilk: "PHP-A",
        //         line: uint(5_000_000 * 10 ** 45), // Set PHP-A limit to 5 million DAI (RAD units)
        //         dust: uint(0),
        //         tau: 1 hours,
        //         mat: uint(1050000000 ether), // Liquidation Ratio (105%),
        //         hole: 5_000_000 * RAD, // Set PHP-A limit to 5 million DAI (RAD units)
        //         chop: 1.13e18, // Set the liquidation penalty (chop) for "PHP-A" to 13% (1.13e18 in WAD units)
        //         buf: 1.20e27, // Set a 20% increase in auctions (RAY)
        //         // duty: 1.0000000018477e27 // 0.00000018477% => 6% Annual duty
        //         duty: 1.0000000012436807e27 // => 4%
        //     }),
        //     PHTDeploy.TokenParams({token: address(0), symbol: "tstPHP", name: "Test PHP", decimals: 6, maxSupply: 0}),
        //     PHTDeploy.FeedParams({
        //         factory: priceFeedFactory,
        //         joinFactory: priceJoinFeedFactory,
        //         feed: address(0),
        //         decimals: 6,
        //         initialPrice: int(1 * 10 ** 6), // Price 1 DAI (PHT) = 1 PHP (precision 6)
        //         numeratorFeed: address(0),
        //         invertNumerator: false,
        //         denominatorFeed: address(0),
        //         invertDenominator: false,
        //         feedDescription: ""
        //     })
        // );

        // Minting of test tokens is for development purposes only
        // php = DSToken(phpAddr);
        // php.mint(5_000_000 * 10 ** 6);
        // php.mint(MULTISIG, 5_000_000 * 10 ** 6);
        // php.mint(TESTER, 5_000_000 * 10 ** 6);

        // (, phpClip, ) = dssDeploy.ilks("PHP-A");

        {
            // Set Liquidation/Auction Rules (Dog)
            proxyActions.file(address(dog), "Hole", _c.dogHoleRad * RAD); // Set global limit to 10 million DAI (RAD units)
            // Set Params for debt ceiling
            proxyActions.file(address(vat), bytes32("Line"), uint(_c.vatLineRad * RAD)); // 10M PHT
            // Set Global Base Fee

            proxyActions.file(address(jug), "base", _c.jugBase); // 0.00000006279% => 2% base global fee

            /// Run initial drip
            // jug.drip("USDT-A");
            // jug.drip("PHP-A");

            // spotter.poke("PHP-A");
            // spotter.poke("USDT-A");
        }

        // TODO: SETUP GemJoinX (usdtJoin is incorrect)
        // psm = new DssPsm(address(usdtJoin), address(daiJoin), address(vow));

        (, , uint spot, , ) = vat.ilks("PHP-A");
        (, , spot, , ) = vat.ilks("USDT-A");

        {
            DSRoles(address(authority)).setUserRole(address(flop), ROLE_GOV_MINT_BURN, true);
            DSRoles(address(authority)).setUserRole(address(flap), ROLE_GOV_MINT_BURN, true);
            DSRoles(address(authority)).setRoleCapability(
                ROLE_GOV_MINT_BURN,
                address(gov),
                bytes4(keccak256("mint(address,uint256)")),
                true
            );
            DSRoles(address(authority)).setRoleCapability(
                ROLE_GOV_MINT_BURN,
                address(gov),
                bytes4(keccak256("burn(address,uint256)")),
                true
            );
        }

        // gov.mint(MULTISIG, 100 ether);
        // address[15] memory relies = [
        //     address(vat),
        //     address(cat),
        //     address(dog),
        //     address(vow),
        //     address(jug),
        //     address(pot),
        //     address(dai),
        //     address(spotter),
        //     address(flap),
        //     address(flop),
        //     address(cure),
        //     address(end),
        //     address(phpClip),
        //     address(usdtClip),
        //     address(ilkRegistry)
        // ];
        // address[] memory reliesdyn = new address[](15);
        // for (uint256 i = 0; i < relies.length; i++) {
        //     reliesdyn[i] = relies[i];
        // }

        // dssDeploy.setAuth(MULTISIG, reliesdyn);
        // dssDeploy.setAuth(TESTER, reliesdyn);
    }

    function chainId() internal view returns (uint256 _chainId) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            _chainId := chainid()
        }
    }

    function convertStaticToDynamic(uint[3] memory fixedArray) public pure returns (uint[] memory) {
        uint[] memory dynamicArray = new uint[](fixedArray.length);
        for (uint i = 0; i < fixedArray.length; i++) {
            dynamicArray[i] = fixedArray[i];
        }
        return dynamicArray;
    }

    function assignAuth(address target) public {
        vat.rely(target);
        cat.rely(target);
        dog.rely(target);
        vow.rely(target);
        jug.rely(target);
        pot.rely(target);
        dai.rely(target);
        spotter.rely(target);
        flap.rely(target);
        flop.rely(target);
        cure.rely(target);
        end.rely(target);
        phpClip.rely(target);
        usdtClip.rely(target);
        ilkRegistry.rely(target);
    }
}

interface ProxyRegistryLike {
    function proxies(address) external view returns (address);
    function build(address) external returns (address);
}

interface ProxyLike {
    function owner() external view returns (address);
    function execute(address target, bytes memory data) external payable returns (bytes memory response);
}

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
