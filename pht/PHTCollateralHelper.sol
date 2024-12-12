pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import {DssDeploy, Clipper} from "lib/dss-cdp-manager/lib/dss-deploy/src/DssDeploy.sol";
import {GemJoin5} from "dss-gem-joins/join-5.sol";
import {GemJoin} from "dss/join.sol";
import {LinearDecrease} from "dss/abaci.sol";
import {IlkRegistry} from "dss-ilk-registry/IlkRegistry.sol";

import {PHTDeploy, PHTDeployResult} from "./PHTDeploy.sol";
import {ConfigurableDSToken} from "./token/ConfigurableDSToken.sol";
import {PriceFeedFactory, PriceFeedAggregator} from "./factory/PriceFeedFactory.sol";
import {PriceJoinFeedFactory, PriceJoinFeedAggregator} from "./factory/PriceJoinFeedFactory.sol";
import {ChainlinkPip, AggregatorV3Interface} from "./helpers/ChainlinkPip.sol";

contract PHTCollateralHelper {
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

    // function deployCollateralClip(bytes32 ilk, address join, address pip, address calc) internal {
    //     require(ilk != bytes32(""), "Missing ilk name");
    //     require(join != address(0), "Missing join address");
    //     require(pip != address(0), "Missing pip address");
    //     require(address(pause) != address(0), "Missing previous step");

    //     // Deploy
    //     ilks[ilk].clip = clipFab.newClip(address(this), address(vat), address(spotter), address(dog), ilk);
    //     ilks[ilk].join = join;
    //     Spotter(spotter).file(ilk, "pip", address(pip)); // Set pip

    //     // Internal references set up
    //     dog.file(ilk, "clip", address(ilks[ilk].clip));
    //     ilks[ilk].clip.file("vow", address(vow));

    //     // Use calc with safe default if not configured
    //     if (calc == address(0)) {
    //         calc = address(calcFab.newLinearDecrease(address(this)));
    //         LinearDecrease(calc).file(bytes32("tau"), 1 hours);
    //     }
    //     ilks[ilk].clip.file("calc", calc);
    //     vat.init(ilk);
    //     jug.init(ilk);

    //     // Internal auth
    //     vat.rely(join);
    //     vat.rely(address(ilks[ilk].clip));
    //     dog.rely(address(ilks[ilk].clip));
    //     ilks[ilk].clip.rely(address(dog));
    //     ilks[ilk].clip.rely(address(end));
    //     ilks[ilk].clip.rely(address(esm));
    //     ilks[ilk].clip.rely(address(pause.proxy()));
    // }

    function addCollateral(
        PHTDeploy dssDeploy,
        // ProxyActions proxyActions,
        IlkRegistry ilkRegistry,
        IlkParams memory ilkParams,
        TokenParams memory tokenParams,
        FeedParams memory feedParams
    ) public returns (address _join, AggregatorV3Interface _feed, address _token, ChainlinkPip _pip) {
        // require(tokenParams.decimals <= 18, "token-factory-max-decimals");
        // @TODO why not extend DSAuth instead?
        // require(ilkRegistry.wards(address(this)) == 1, "dss-deploy-ext-ilkreg-not-authorized");

        address owner = dssDeploy.owner();

        _token = tokenParams.token;
        if (_token == address(0)) {
            ConfigurableDSToken newToken = new ConfigurableDSToken(
                tokenParams.symbol,
                tokenParams.name,
                tokenParams.decimals,
                tokenParams.maxSupply
            );

            // Minting of test tokens is for development purposes only
            newToken.mint(msg.sender, tokenParams.maxSupply);

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
            _join = address(new GemJoin5(address(dssDeploy.vat()), ilkParams.ilk, _token));
        } else {
            _join = address(new GemJoin(address(dssDeploy.vat()), ilkParams.ilk, _token));
        }

        {
            LinearDecrease _calc = dssDeploy.calcFab().newLinearDecrease(address(this));
            _calc.file(bytes32("tau"), ilkParams.tau);
            _calc.rely(owner);
            _calc.deny(address(this));
            dssDeploy.deployCollateralClip(ilkParams.ilk, _join, address(_pip), address(_calc));
        }

        {
            dssDeploy.vat().file(ilkParams.ilk, bytes32("line"), ilkParams.line);
            dssDeploy.vat().file(ilkParams.ilk, bytes32("dust"), ilkParams.dust);
            dssDeploy.spotter().file(ilkParams.ilk, bytes32("mat"), ilkParams.mat);
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

        // moved to PHTDeploy
        ilkRegistry.add(_join);
        dssDeploy.spotter().poke(ilkParams.ilk);
    }
}
