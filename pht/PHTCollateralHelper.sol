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
import {PHTTokenHelper} from "./PHTTokenHelper.sol";

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
        uint256 maxSupply; // maxSupply == 0 => unlimited supply
        uint256 initialSupply; // initialSupply == 0 => no initial supply
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
        uint256 line; // Ilk Debt ceiling [RAD]
        uint256 dust; // Ilk Urn Debt floor [RAD]
        uint256 tau; // Default: 1 hours
        uint256 mat; // Liquidation Ratio [RAY]
        uint256 hole; // Gem-limit [RAD]
        uint256 chop; // Liquidation-penalty [WAD]
        uint256 buf; // Initial Auction Increase [RAY]
        uint256 duty; // Jug: ilk fee [RAY]
    }

    constructor(Vat vat_, Spotter spotter_, Dog dog_, Vow vow_, Jug jug_, End end_, ESM esm_, DSPause pause_) public {
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
        require(address(calcFab) == address(0), "pht-collateral-helper-fabs-init");
        calcFab = calcFab_;
        clipFab = clipFab_;
        gemJoinFab = gemJoinFab_;
        gemJoin5Fab = gemJoin5Fab_;
    }

    function setTokenHelper(PHTTokenHelper tokenHelper_) public auth {
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

    // @TODO return masterMinter
    // @TODO reuse masterMinter?
    function addCollateral(
        // @TOOD avoid shadowing owner from base class DSAuth
        address owner,
        address ilkRegistry,
        IlkParams memory ilkParams,
        TokenParams memory tokenParams,
        FeedParams memory feedParams
    ) public auth returns (address _join, AggregatorV3Interface _feed, address _token, ChainlinkPip _pip) {
        _token = tokenParams.token;
        if (_token == address(0)) {
            FiatTokenInfo memory info = FiatTokenInfo({
                tokenName: tokenParams.name,
                tokenSymbol: tokenParams.symbol,
                tokenDecimals: tokenParams.decimals,
                // @TODO needs FE update
                tokenCurrency: "",
                initialSupply: tokenParams.initialSupply,
                initialSupplyMintTo: msg.sender,
                masterMinterOwner: address(tokenHelper),
                // @TODO proxyAdmin cannot be the same as owner
                // update Proxy actions to allow update of implementation of FiatProxy
                proxyAdmin: address(pause.proxy()),
                // Ideally this should be PHTTokenHelper
                pauser: address(tokenHelper),
                blacklister: address(tokenHelper),
                owner: address(tokenHelper)
            });

            (address implementation, address proxy, address masterMinter) =
                ITokenFactory(tokenParams.factory).create(info);

            tokenHelper.configureMinter(masterMinter);

            // newToken.setOwner(owner);
            _token = address(proxy);
        }

        _feed = AggregatorV3Interface(feedParams.feed);
        if (address(_feed) == address(0)) {
            if (feedParams.numeratorFeed != address(0)) {
                PriceJoinFeedAggregator feed = feedParams.joinFactory.create(
                    feedParams.numeratorFeed,
                    feedParams.denominatorFeed,
                    feedParams.invertNumerator,
                    feedParams.invertDenominator,
                    feedParams.feedDescription
                );
                feed.setOwner(owner);
                _feed = AggregatorV3Interface(address(feed));
            } else {
                PriceFeedAggregator feed = feedParams.factory.create(feedParams.decimals, feedParams.initialPrice, "");
                feed.setOwner(owner);
                _feed = AggregatorV3Interface(address(feed));
            }
        }
        _pip = new ChainlinkPip(address(_feed));

        // @TODO deny this ward in GemJoin(s)
        if (TokenLike(_token).decimals() < 18) {
            _join = address(gemJoin5Fab.newJoin(owner, address(vat), ilkParams.ilk, _token));
        } else {
            _join = address(gemJoinFab.newJoin(owner, address(vat), ilkParams.ilk, _token));
        }

        {
            LinearDecrease _calc = calcFab.newLinearDecrease(address(this));
            _calc.file(bytes32("tau"), ilkParams.tau);
            _calc.rely(owner);
            _calc.deny(address(this));

            deployCollateralClip(ilkParams.ilk, _join, address(_pip), address(_calc));
        }

        {
            vat.file(ilkParams.ilk, bytes32("line"), ilkParams.line);
            vat.file(ilkParams.ilk, bytes32("dust"), ilkParams.dust);
            vat.rely(address(_join));
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
