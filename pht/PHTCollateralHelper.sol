pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import {DSAuth, DSAuthority} from "ds-auth/auth.sol";
import {DSPause} from "ds-pause/pause.sol";

import {Vat} from "dss/vat.sol";
import {Jug} from "dss/jug.sol";
import {Vow} from "dss/vow.sol";
import {Cat} from "dss/cat.sol";
import {Dog} from "dss/dog.sol";
import {Spotter} from "dss/spot.sol";
import {Clipper} from "dss/clip.sol";
import {End} from "dss/end.sol";
import {ESM} from "esm/ESM.sol";

import {CalcFab, ClipFab} from "dss-deploy/DssDeploy.sol";
import {GemJoin5} from "dss-gem-joins/join-5.sol";
import {GemJoin} from "dss/join.sol";
import {LinearDecrease} from "dss/abaci.sol";
import {IlkRegistry} from "dss-ilk-registry/IlkRegistry.sol";

import {PHTDeploy, PHTDeployResult} from "./PHTDeploy.sol";
import {ConfigurableDSToken} from "./token/ConfigurableDSToken.sol";
import {PriceFeedFactory, PriceFeedAggregator} from "./factory/PriceFeedFactory.sol";
import {PriceJoinFeedFactory, PriceJoinFeedAggregator} from "./factory/PriceJoinFeedFactory.sol";
import {ChainlinkPip, AggregatorV3Interface} from "./helpers/ChainlinkPip.sol";

interface TokenLike {
    function decimals() external returns (uint8);
}
interface FactoryLike {
    function create(bytes memory payload) external returns (address);
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

    constructor(
        Vat vat_,
        Spotter spotter_,
        Dog dog_,
        Vow vow_,
        Jug jug_,
        End end_,
        ESM esm_,
        DSPause pause_,
        CalcFab calcFab_,
        ClipFab clipFab_
    ) public {
        vat = vat_;
        spotter = spotter_;
        dog = dog_;
        vow = vow_;
        jug = jug_;
        end = end_;
        esm = esm_;
        pause = pause_;
        calcFab = calcFab_;
        clipFab = clipFab_;

        authority = DSAuthority(pause.authority());
    }

    struct TokenParams {
        address token; // optional
        // FactoryLike factory;
        // bytes payload;

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
        int initialPrice; // (optional) feed price
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

    function deployCollateralClip(
        bytes32 ilk,
        address join,
        address pip,
        address calc
    ) internal returns (Clipper clip) {
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
        // ProxyActions proxyActions,
        address owner,
        IlkRegistry ilkRegistry,
        IlkParams memory ilkParams,
        TokenParams memory tokenParams,
        FeedParams memory feedParams
    ) public auth returns (address _join, AggregatorV3Interface _feed, address _token, ChainlinkPip _pip) {
        // require(tokenParams.decimals <= 18, "token-factory-max-decimals");
        // @TODO why not extend DSAuth instead?
        require(ilkRegistry.wards(address(this)) == 1, "dss-deploy-ext-ilkreg-not-authorized");

        _token = tokenParams.token;
        if (_token == address(0)) {
            ConfigurableDSToken newToken = new ConfigurableDSToken(
                tokenParams.symbol,
                tokenParams.name,
                tokenParams.decimals,
                tokenParams.maxSupply
            );

            if (tokenParams.initialSupply > 0) {
                newToken.mint(msg.sender, tokenParams.initialSupply);
            }

            newToken.setOwner(owner);
            _token = address(newToken);
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

        if (tokenParams.decimals < 18) {
            _join = address(new GemJoin5(address(vat), ilkParams.ilk, _token));
        } else {
            _join = address(new GemJoin(address(vat), ilkParams.ilk, _token));
        }

        LinearDecrease _calc = calcFab.newLinearDecrease(address(this));
        _calc.file(bytes32("tau"), ilkParams.tau);
        _calc.rely(owner);
        _calc.deny(address(this));

        deployCollateralClip(ilkParams.ilk, _join, address(_pip), address(_calc));

        vat.file(ilkParams.ilk, bytes32("line"), ilkParams.line);
        vat.file(ilkParams.ilk, bytes32("dust"), ilkParams.dust);
        vat.rely(address(_join));
        spotter.file(ilkParams.ilk, bytes32("mat"), ilkParams.mat);

        dog.file(ilkParams.ilk, "hole", ilkParams.hole); // Set PHP-A limit to 5 million DAI (RAD units)
        dog.file("Hole", ilkParams.hole + dog.Hole()); // Increase global limit
        dog.file(ilkParams.ilk, "chop", ilkParams.chop); // Set the liquidation penalty (chop) for "PHP-A" to 13% (1.13e18 in WAD units)

        (address clip, , , ) = dog.ilks(ilkParams.ilk);
        Clipper(clip).file("buf", ilkParams.buf); // Set a 20% increase in auctions (RAY)

        // Set Ilk Fees
        jug.file(ilkParams.ilk, "duty", ilkParams.duty); // 6% duty fee;
        jug.drip(ilkParams.ilk);
        ilkRegistry.add(_join);
        spotter.poke(ilkParams.ilk);
    }
}
