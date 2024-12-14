pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "forge-std/console.sol";
import "forge-std/StdCheats.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// import everything that DssDeploy imports
import "dss-deploy/DssDeploy.sol";
import {GovActions} from "dss-deploy/govActions.sol";
import {DSAuth, DSAuthority} from "ds-auth/auth.sol";
import {DSTest} from "ds-test/test.sol";
import {DSToken} from "ds-token/token.sol";
import {DSValue} from "ds-value/value.sol";
import {GemJoin} from "dss/join.sol";
import {LinearDecrease} from "dss/abaci.sol";
import {DssPsm} from "dss-psm/psm.sol";
import {IlkRegistry} from "dss-ilk-registry/IlkRegistry.sol";
import {DssProxyActions, DssProxyActionsEnd, DssProxyActionsDsr} from "dss-proxy-actions/DssProxyActions.sol";
import {DssCdpManager} from "dss-cdp-manager/DssCdpManager.sol";
import {DsrManager} from "dsr-manager/DsrManager.sol";
import {GemJoin5} from "dss-gem-joins/join-5.sol";
import {DssAutoLine} from "dss-auto-line/DssAutoLine.sol";
import {MkrAuthority} from "mkr-authority/MkrAuthority.sol";

// --- custom code ---
import {DSRoles} from "./lib/Roles.sol";
import {ChainLog} from "../test/helpers/ChainLog.sol";

// Chainlink
import {PriceFeedFactory, PriceFeedAggregator} from "./factory/PriceFeedFactory.sol";
import {PriceJoinFeedFactory, PriceJoinFeedAggregator} from "./factory/PriceJoinFeedFactory.sol";
import {ChainlinkPip, AggregatorV3Interface} from "./helpers/ChainlinkPip.sol";
import {ConfigurableDSToken} from "./token/ConfigurableDSToken.sol";
import {PHTDeployConfig} from "./PHTDeployConfig.sol";
import {PHTCollateralHelper} from "./PHTCollateralHelper.sol";
import {ProxyActions} from "./helpers/ProxyActions.sol";

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

struct PHTDeployResult {
    // --- Auth ---
    address authority;
    address mkrAuthority;
    address dssProxyActions;
    address dssProxyActionsEnd;
    address dssProxyActionsDsr;
    address dssProxyRegistry;
    address proxyActions;
    address dssCdpManager;
    address dsrManager;
    address gov;
    address ilkRegistry;
    address pause;
    // --- MCD ---
    address vat;
    address jug;
    address vow;
    address cat;
    address dog;
    address flap;
    address flop;
    address dai;
    address daiJoin;
    address spotter;
    address pot;
    address cure;
    address end;
    address esm;
    // --- ChainLog ---
    address clog;
    // --- Factories ---
    address feedFactory;
    address joinFeedFactory;
    // --- Helpers ----
    address collateralHelper;
}

contract PHTDeploy is DssDeploy, StdCheats {
    DssProxyActions dssProxyActions;
    DssProxyActionsEnd dssProxyActionsEnd;
    DssProxyActionsDsr dssProxyActionsDsr;
    DssCdpManager dssCdpManager;
    DsrManager dsrManager;
    ProxyActions proxyActions;
    GovActions govActions;
    DSToken gov;
    MkrAuthority mkrAuthority;
    PriceFeedFactory feedFactory;
    PriceJoinFeedFactory joinFeedFactory;
    PHTCollateralHelper collateralHelper;

    ChainLog clog;
    DssAutoLine autoline;
    IlkRegistry ilkRegistry;

    // -- ROLES --
    uint8 constant ROLE_GOV_MINT_BURN = 10;
    uint8 constant ROLE_GOV_ADD_COLLATERAL = 10;

    uint8 constant ROLE_CAN_PLOT = 11;
    uint8 constant ROLE_CAN_EXEC = 12;

    // --- Math ---
    uint256 constant WAD = 10 ** 18;
    uint256 constant RAY = 10 ** 27;
    uint256 constant RAD = 10 ** 45;

    function deploy(PHTDeployConfig memory _c) public returns (PHTDeployResult memory) {
        require(_c.authorityRootUsers.length > 0, "> authorityRootUsers");
        require(_c.authorityOwner != address(0), "authorityOwner required");

        // @TODO add MkrAuthority makerdao/mkr-authority/src/MkrAuthority.sol

        PHTDeployResult memory result;
        result.authority = address(deployAuthority(_c.authorityRootUsers));
        (result.gov, result.mkrAuthority) = deployGovAndMkrAuthority(_c.govTokenSymbol);

        // --- Fabs ---
        deployFabs();
        deployKeepAuth(_c, result.authority);
        // after pause is deployed we can now set perms on MkrAuthority and GOV token
        setGovAndMkrAuthorityPerms();

        result.dssProxyRegistry = deployDssProxyRegistry();

        // release auth
        this.releaseAuth();
        // release authority owner
        DSRoles(address(authority)).setOwner(_c.authorityOwner);

        // TODO: Release
        // dssDeploy.releaseAuthFlip("ETH", address(dssDeploy));
        // dssDeploy.releaseAuthClip("PHP-A", address(dssDeploy));
        // dssDeploy.releaseAuthClip("USDT-A", address(dssDeploy));
        // testReleasedAuth();

        {
            result.vat = address(vat);
            result.jug = address(jug);
            result.vow = address(vow);
            result.cat = address(cat);
            result.dog = address(dog);
            result.flap = address(flap);
            result.flop = address(flop);
            result.dai = address(dai);
            result.daiJoin = address(daiJoin);
            result.spotter = address(spotter);
            result.pot = address(pot);
            result.cure = address(cure);
            result.end = address(end);
            result.esm = address(esm);

            result.dssProxyActions = address(dssProxyActions);
            result.dssProxyActionsEnd = address(dssProxyActionsEnd);
            result.dssProxyActionsDsr = address(dssProxyActionsDsr);
            result.proxyActions = address(proxyActions);
            result.pause = address(pause);
            result.dssCdpManager = address(dssCdpManager);
            result.dsrManager = address(dsrManager);
            result.ilkRegistry = address(ilkRegistry);
            result.feedFactory = address(feedFactory);
            result.joinFeedFactory = address(joinFeedFactory);
            result.collateralHelper = address(collateralHelper);
        }

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
            // clog.setAddress("MCD_PSM", address(psm));
            clog.setAddress("MCD_ILKS", address(ilkRegistry));
            clog.setAddress("MCD_DSS_PROXY_ACTIONS", address(dssProxyActions));
            clog.setAddress("MCD_DSS_PROXY_CDP_MANAGER", address(dssCdpManager));
            clog.setAddress("MCD_PROXY_DSR_MANAGER", address(dsrManager));
            clog.setIPFS("");

            result.clog = address(clog);
        }

        return result;
    }

    function deployAuthority(address[] memory _rootUsers) private returns (DSRoles) {
        authority = new DSRoles();
        uint256 l = _rootUsers.length;
        require(l > 0);

        for (uint256 i = 0; i < l; i++) {
            DSRoles(address(authority)).setRootUser(_rootUsers[i], true);
        }

        return DSRoles(address(authority));
    }

    function deployFabs() private {
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
    }

    function deployGovAndMkrAuthority(string memory _govSymbol) private returns (address, address) {
        // @see https://github.com/makerdao/dss-deploy-scripts/blob/85c2a6a7046ec618596b47e5259090dad0269a5f/libexec/base-deploy
        // L134
        mkrAuthority = new MkrAuthority();

        // GOV token
        gov = new DSToken(_govSymbol);
        gov.setAuthority(DSAuthority(address(mkrAuthority)));

        return (address(gov), address(mkrAuthority));
    }

    function setGovAndMkrAuthorityPerms() private {
        // @see https://github.com/makerdao/dss-deploy-scripts/blob/85c2a6a7046ec618596b47e5259090dad0269a5f/libexec/base-deploy
        // # Set GOV_GUARD as authority of MCD_GOV
        // sethSend "$MCD_GOV" 'setAuthority(address)' "$GOV_GUARD"
        // # Set ownership to MCD_PAUSE_PROXY
        // sethSend "$MCD_GOV" 'setOwner(address)' "$MCD_PAUSE_PROXY"
        // # Allow Flop to mint Gov token
        // sethSend "$GOV_GUARD" 'rely(address)' "$MCD_FLOP"
        // # Set root to MCD_PAUSE_PROXY
        // sethSend "$GOV_GUARD" 'setRoot(address)' "$MCD_PAUSE_PROXY"

        // Allow Flop to mint Gov token
        mkrAuthority.rely(address(flop));
        // Set root to MCD_PAUSE_PROXY
        mkrAuthority.setRoot(address(pause.proxy()));
        // Set ownership to MCD_PAUSE_PROXY
        gov.setOwner(address(pause.proxy()));
    }

    function deployKeepAuth(PHTDeployConfig memory _c, address _authority) public {
        this.deployVat();
        this.deployDai(chainId());
        this.deployTaxation();
        this.deployAuctions(address(gov));
        this.deployLiquidator();
        this.deployEnd();
        // @TODO set pauseDelay to non-zero?
        this.deployPause(0, _authority);

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

        autoline = new DssAutoLine(address(vat));
        dssProxyActions = new DssProxyActions();
        dssProxyActionsEnd = new DssProxyActionsEnd();
        dssProxyActionsDsr = new DssProxyActionsDsr();

        govActions = new GovActions();
        proxyActions = new ProxyActions(address(pause), address(govActions));
        dssCdpManager = new DssCdpManager(address(vat));
        dsrManager = new DsrManager(address(pot), address(daiJoin));

        feedFactory = new PriceFeedFactory();
        joinFeedFactory = new PriceJoinFeedFactory();

        // SetupIlkRegistry
        ilkRegistry = new IlkRegistry(address(vat), address(dog), address(cat), address(spotter));
        ilkRegistry.rely(address(pause.proxy()));

        // Setup CollateralHelper
        collateralHelper = new PHTCollateralHelper(
            vat,
            spotter,
            dog,
            vow,
            jug,
            end,
            esm,
            pause,
            this.calcFab(),
            this.clipFab()
        );
        console.log("[PHTDeploy] collateralHelper \t", address(collateralHelper));
        vat.rely(address(collateralHelper));
        spotter.rely(address(collateralHelper));
        dog.rely(address(collateralHelper));
        ilkRegistry.rely(address(collateralHelper));
        jug.rely(address(collateralHelper));

        DSRoles(address(authority)).setUserRole(address(proxyActions), ROLE_CAN_PLOT, true);
        DSRoles(address(authority)).setRoleCapability(
            ROLE_CAN_PLOT,
            address(this.pause()),
            bytes4(keccak256("plot(address,bytes32,bytes,uint256)")),
            true
        );
        // DSRoles(address(authority)).setRoleCapability(
        //     ROLE_CAN_EXEC,
        //     address(this.pause().proxy()),
        //     bytes4(keccak256("exec(address,bytes32,bytes,uint256)")),
        //     true
        // );

        DSRoles(address(authority)).setRoleCapability(
            ROLE_GOV_ADD_COLLATERAL,
            address(collateralHelper),
            collateralHelper.addCollateral.selector,
            true
        );

        {
            // Set Liquidation/Auction Rules (Dog)
            dog.file("Hole", _c.dogHoleRad * RAD); // Set global limit to 10 million DAI (RAD units)
            // Set Params for debt ceiling
            vat.file("Line", uint(_c.vatLineRad * RAD)); // 10M PHT
            // Set Global Base Fee

            jug.file("base", _c.jugBase); // 0.00000006279% => 2% base global fee

            /// Run initial drip
            // jug.drip("USDT-A");
            // jug.drip("PHP-A");

            // spotter.poke("PHP-A");
            // spotter.poke("USDT-A");
        }

        // TODO: SETUP GemJoinX (usdtJoin is incorrect)
        // psm = new DssPsm(address(usdtJoin), address(daiJoin), address(vow));

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
    }

    function deployDssProxyRegistry() private returns (address) {
        // path needs to match the `out` path in foundry.toml
        return deployCode("./out_pht/DssProxyRegistry.sol/DssProxyRegistry.json");
    }

    function chainId() internal view returns (uint256 _chainId) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            _chainId := chainid()
        }
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
