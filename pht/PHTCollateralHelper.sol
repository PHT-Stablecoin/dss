pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import {DSAuth, DSAuthority} from "ds-auth/auth.sol";
import {DSPause} from "ds-pause/pause.sol";

import "dss-deploy/DssDeploy.sol";
import {Jug} from "dss/jug.sol";
import {Vow} from "dss/vow.sol";
import {Cat} from "dss/cat.sol";
import {Spotter} from "dss/spot.sol";
import {Clipper} from "dss/clip.sol";
import {End} from "dss/end.sol";
import {ESM} from "esm/ESM.sol";

import {GemJoin5} from "dss-gem-joins/join-5.sol";
import {GemJoin} from "dss/join.sol";
import {LinearDecrease} from "dss/abaci.sol";

import {PriceFeedFactory, PriceFeedAggregator} from "./factory/PriceFeedFactory.sol";
import {PriceJoinFeedFactory, PriceJoinFeedAggregator} from "./factory/PriceJoinFeedFactory.sol";
import {ChainlinkPip, AggregatorV3Interface} from "./helpers/ChainlinkPip.sol";
import {PHTTokenHelper, TokenInfo} from "./PHTTokenHelper.sol";

import {ITokenFactory} from "../fiattoken/FiatTokenFactory.sol";
import {FiatTokenInfo} from "../fiattoken/TokenTypes.sol";

interface TokenLike {
    function decimals() external returns (uint8);
}

interface IlkRegistryLike {
    function wards(address user) external view returns (uint256);
    function add(address join) external;
}

contract GemJoinFab {
    function newJoin(address owner, address vat, bytes32 ilk, address token) public returns (GemJoin join) {
        join = new GemJoin(vat, ilk, token);
        join.rely(owner);
        join.deny(address(this));
    }
}

contract GemJoin5Fab {
    function newJoin(address owner, address vat, bytes32 ilk, address token) public returns (GemJoin5 join) {
        join = new GemJoin5(vat, ilk, token);
        join.rely(owner);
        join.deny(address(this));
    }
}

contract PHTCollateralHelper is DSAuth {
    Vat public vat;
    Spotter public spotter;
    Dog public dog;
    Vow public vow;
    Jug public jug;
    End public end;
    ESM public esm;
    DSPause public pause;

    CalcFab calcFab;
    ClipFab clipFab;
    GemJoinFab gemJoinFab;
    GemJoin5Fab gemJoin5Fab;

    PHTTokenHelper public tokenHelper;

    struct TokenParams {
        ITokenFactory factory;
        address token; // optional
        string name;
        string symbol;
        uint8 decimals;
        string currency;
        uint256 maxSupply; // maxSupply == 0 => unlimited supply
        uint256 initialSupply; // initialSupply == 0 => no initial supply
        address initialSupplyMintTo;
        address tokenAdmin;
    }

    struct FeedParams {
        // address feed;
        // FactoryLike factory;
        // bytes payload;
        PriceFeedFactory factory;
        PriceJoinFeedFactory joinFactory;
        address feed; // (optional)
        int256 initialPrice; // (optional) feed price
        uint8 decimals; // Default: (6 decimals)
        address numeratorFeed; // (optional)
        address denominatorFeed;
        bool invertNumerator;
        bool invertDenominator;
        string feedDescription;
    }

    struct IlkParams {
        bytes32 ilk;
        uint256 line; // Ilk Debt ceiling                                                  [rad]
        uint256 dust; // Ilk Urn Debt floor                                                [rad]
        uint256 tau; // Default: 1 hours
        uint256 mat; // Liquidation Ratio                                                  [ray]
        uint256 hole; // Gem-limit                                                         [rad]
        uint256 chop; // Liquidation-penalty                                               [wad]
        uint256 buf; // Multiplicative factor to increase starting price                   [ray]
        uint256 duty; // Jug: ilk fee                                                      [ray]
        uint256 tail; // Time elapsed before auction reset                                 [seconds]
        uint256 cusp; // Percentage drop before auction reset                              [ray]
        uint64 chip; // Percentage of tab to suck from vow to incentivize keepers          [wad]
        uint192 tip; // Flat fee to suck from vow to incentivize keepers                   [rad]
            // uint256 chost;  // Cache the ilk dust times the ilk chop to prevent excessive SLOADs [rad]
    }

    constructor(Vat vat_, Spotter spotter_, Dog dog_, Vow vow_, Jug jug_, End end_, ESM esm_, DSPause pause_) public {
        require(address(vat_) != address(0), "PHTCollateralHelper/vat-not-set");
        require(address(spotter_) != address(0), "PHTCollateralHelper/spotter-not-set");
        require(address(dog_) != address(0), "PHTCollateralHelper/dog-not-set");
        require(address(vow_) != address(0), "PHTCollateralHelper/vow-not-set");
        require(address(jug_) != address(0), "PHTCollateralHelper/jug-not-set");
        require(address(end_) != address(0), "PHTCollateralHelper/end-not-set");
        require(address(esm_) != address(0), "PHTCollateralHelper/esm-not-set");
        require(address(pause_) != address(0), "PHTCollateralHelper/pause-not-set");

        vat = vat_;
        spotter = spotter_;
        dog = dog_;
        vow = vow_;
        jug = jug_;
        end = end_;
        esm = esm_;
        pause = pause_;
        authority = DSAuthority(pause.authority());
    }

    function setFabs(CalcFab calcFab_, ClipFab clipFab_, GemJoinFab gemJoinFab_, GemJoin5Fab gemJoin5Fab_)
        public
        auth
    {
        require(address(calcFab) == address(0), "PHTCollateralHelper/calcFab-inited");
        require(address(calcFab_) != address(0), "PHTCollateralHelper/calcFab-not-set");
        require(address(clipFab_) != address(0), "PHTCollateralHelper/clipFab-not-set");
        require(address(gemJoinFab_) != address(0), "PHTCollateralHelper/gemJoinFab-not-set");
        require(address(gemJoin5Fab_) != address(0), "PHTCollateralHelper/gemJoin5Fab-not-set");

        calcFab = calcFab_;
        clipFab = clipFab_;
        gemJoinFab = gemJoinFab_;
        gemJoin5Fab = gemJoin5Fab_;
    }

    function setTokenHelper(PHTTokenHelper tokenHelper_) public auth {
        require(address(tokenHelper_) != address(0), "PHTCollateralHelper/token-helper-not-set");
        tokenHelper = tokenHelper_;
    }

    function deployCollateralClip(bytes32 ilk, address join, address pip, address calc)
        internal
        returns (Clipper clip)
    {
        require(ilk != bytes32(""), "Missing ilk name");
        require(join != address(0), "Missing join address");
        require(pip != address(0), "Missing pip address");
        require(calc != address(0), "Missing calc address");

        require(address(pause) != address(0), "Missing previous step");

        // Deploy
        clip = clipFab.newClip(address(this), address(vat), address(spotter), address(dog), ilk);
        spotter.file(ilk, "pip", pip); // Set pip

        // Internal references set up
        dog.file(ilk, "clip", address(clip));
        clip.file("vow", address(vow));
        clip.file("calc", calc);

        vat.init(ilk);
        jug.init(ilk);

        // Internal auth
        vat.rely(join);
        vat.rely(address(clip));
        dog.rely(address(clip));
        clip.rely(address(dog));
        clip.rely(address(end));
        clip.rely(address(esm));
        clip.rely(address(pause.proxy()));
    }

    function addCollateral(
        address ilkRegistry,
        IlkParams memory ilkParams,
        TokenParams memory tokenParams,
        FeedParams memory feedParams
    ) public auth returns (address _join, AggregatorV3Interface _feed, address _token, ChainlinkPip _pip) {
        _token = tokenParams.token;
        if (_token == address(0)) {
            TokenInfo memory info = TokenInfo({
                tokenName: tokenParams.name,
                tokenSymbol: tokenParams.symbol,
                tokenDecimals: tokenParams.decimals,
                tokenCurrency: tokenParams.currency,
                initialSupply: tokenParams.initialSupply,
                initialSupplyMintTo: tokenParams.initialSupplyMintTo,
                tokenAdmin: tokenParams.tokenAdmin
            });

            (,, address proxy,) = PHTTokenHelper(tokenHelper).createToken(info);

            _token = address(proxy);
        }

        _feed = AggregatorV3Interface(feedParams.feed);
        if (address(_feed) == address(0)) {
            address proxy = address(pause.proxy());
            if (feedParams.numeratorFeed != address(0)) {
                PriceJoinFeedAggregator feed = feedParams.joinFactory.create(
                    feedParams.numeratorFeed,
                    feedParams.denominatorFeed,
                    feedParams.invertNumerator,
                    feedParams.invertDenominator,
                    feedParams.feedDescription
                );
                feed.setOwner(proxy);
                _feed = AggregatorV3Interface(address(feed));
            } else {
                PriceFeedAggregator feed = feedParams.factory.create(feedParams.decimals, feedParams.initialPrice, "");
                feed.setOwner(proxy);
                _feed = AggregatorV3Interface(address(feed));
            }
        }
        _pip = new ChainlinkPip(address(_feed));

        // @TODO deny this ward in GemJoin(s)
        if (TokenLike(_token).decimals() < 18) {
            _join = address(gemJoin5Fab.newJoin(address(pause.proxy()), address(vat), ilkParams.ilk, _token));
        } else {
            _join = address(gemJoinFab.newJoin(address(pause.proxy()), address(vat), ilkParams.ilk, _token));
        }

        {
            LinearDecrease _calc = calcFab.newLinearDecrease(address(this));
            _calc.file(bytes32("tau"), ilkParams.tau);
            _calc.rely(address(pause.proxy()));
            _calc.deny(address(this));

            deployCollateralClip(ilkParams.ilk, _join, address(_pip), address(_calc));
        }

        {
            vat.file(ilkParams.ilk, bytes32("line"), ilkParams.line);
            vat.file(ilkParams.ilk, bytes32("dust"), ilkParams.dust);
            spotter.file(ilkParams.ilk, bytes32("mat"), ilkParams.mat);
        }

        {
            dog.file(ilkParams.ilk, "hole", ilkParams.hole); // Set PHP-A limit to 5 million DAI (RAD units)
            dog.file("Hole", ilkParams.hole + dog.Hole()); // Increase global limit
            dog.file(ilkParams.ilk, "chop", ilkParams.chop); // Set the liquidation penalty (chop) for "PHP-A" to 13% (1.13e18 in WAD units)
        }

        {
            (address clip,,,) = dog.ilks(ilkParams.ilk);
            Clipper(clip).file("buf", ilkParams.buf); // Set a 20% increase in auctions (RAY)
            Clipper(clip).file("tail", ilkParams.tail);
            Clipper(clip).file("cusp", ilkParams.cusp);
            Clipper(clip).file("chip", ilkParams.chip);
            Clipper(clip).file("tip", ilkParams.tip);
            Clipper(clip).deny(address(this));
            Clipper(clip).upchost();
        }

        {
            // Set Ilk Fees
            jug.file(ilkParams.ilk, "duty", ilkParams.duty); // 6% duty fee;
            jug.drip(ilkParams.ilk);
            IlkRegistryLike(ilkRegistry).add(_join);
            spotter.poke(ilkParams.ilk);
        }
    }
}

interface VatLinke {
    function file(bytes32 ilk, bytes32 what, uint256 data) external;
    function init(bytes32 ilk) external;
    function rely(address usr) external;
    function deny(address usr) external;
}

interface DogLike {
    function ilks(bytes32) external returns (address clip, uint256 chop, uint256 hole, uint256 dirt);
    function file(bytes32 ilk, bytes32 what, uint256 data) external;
    function file(bytes32 ilk, string memory what, address data) external;
    function file(bytes32 what, uint256 data) external;
    function rely(address usr) external;
    function Hole() external returns (uint256);
}

interface CalcFabLike {
    function newLinearDecrease(address owner) external returns (address);
}

interface ClipFabLike {
    function newClip(address owner, address vat, address spotter, address dog, bytes32 ilk)
        external
        returns (address);
}
