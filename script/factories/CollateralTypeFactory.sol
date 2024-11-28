// pragma solidity ^0.6.12;
// pragma experimental ABIEncoderV2;

// import {DSAuth} from "ds-auth/auth.sol";
// import {Vat} from "dss/vat.sol";
// import {Spotter} from "dss/spot.sol";
// import {Jug} from "dss/jug.sol";
// import {LinearDecrease} from "dss/abaci.sol";
// import {ProxyActions} from "../../test/helpers/ProxyActions.sol";
// import {IlkRegistry} from "dss-ilk-registry/IlkRegistry.sol";
// import {GemJoin} from "dss/join.sol";
// import {GemJoin5} from "dss-gem-joins/join-5.sol";
// import {TokenFactory} from "./TokenFactory.sol";
// import {PriceFeedAggregator} from "./PriceFeedAggregator.sol";
// import {ChainlinkPip} from "../../test/helpers/ChainlinkPip.sol";

// interface GemLike {
//     function balanceOf(address) external view returns (uint256);
//     function burn(uint256) external;
//     function transfer(address, uint256) external returns (bool);
//     function transferFrom(address, address, uint256) external returns (bool);
// }

// interface GemJoinLike {
//     function dec() external returns (uint);
//     function gem() external returns (GemLike);
//     function join(address, uint) external payable;
//     function exit(address, uint) external;
// }

// contract CollateralTypeFactory is DSAuth {
//     // Core contracts
//     Vat public immutable vat;
//     Spotter public immutable spotter;
//     Jug public immutable jug;
//     ProxyActions public immutable proxyActions;
//     IlkRegistry public immutable ilkRegistry;

//     struct PriceFeedInfo {
//         address feedAddress; // Address of the deployed price feed
//         string description; // Description of what this feed represents
//         uint8 decimals; // Decimal precision of the feed
//         bool exists; // Exists flag for registration check
//     }
//     // Parameters for collateral configuration
//     struct CollateralParams {
//         // Token parameters
//         string symbol;
//         string name;
//         uint8 decimals;
//         uint256 maxSupply;
//         // bool isStandardToken; // If true, creates DSToken, if false creates ConfigurableDSToken
//         // Price feed parameters
//         int256 initialPrice; // Initial price in price feed decimals
//         // Risk parameters
//         uint256 debtCeiling; // Maximum debt ceiling (in DAI)
//         uint256 liquidationFee; //
//         uint256 liquidationRatio; // Minimum collateralization ratio (e.g., 150% = 1.5 * WAD)
//         uint256 stabilityFee; // Yearly stability fee (e.g., 2% = 1.02 * WAD)
//         bool isSelfManageToken;
//         address tokenAddress;
//         // Price feed params
//         bool isSelfManagePriceFeed;
//         address priceFeedAddress;
//     }

//     // Collateral tracking
//     struct CollateralInfo {
//         address token; // Token address
//         address join; // GemJoin adapter address
//         address pip; // ChainlinkPip address
//         address aggregator; // Price feed aggregator address
//         bytes32 ilk; // Collateral identifier
//         bool exists; // Registration check
//     }

//     mapping(bytes32 => CollateralInfo) public collaterals;

//     event CollateralTypeCreated(
//         bytes32 indexed ilk,
//         address token,
//         address join,
//         address pip,
//         address aggregator,
//         uint256 debtCeiling
//     );

//     constructor(
//         address _vat,
//         address _spotter,
//         address _jug,
//         address _proxyActions,
//         address _ilkRegistry,
//         address _tokenFactory,
//         address _priceFeedFactory
//     ) public {
//         vat = Vat(_vat);
//         spotter = Spotter(_spotter);
//         jug = Jug(_jug);
//         proxyActions = ProxyActions(_proxyActions);
//         ilkRegistry = IlkRegistry(_ilkRegistry);
//         tokenFactory = TokenFactory(_tokenFactory);
//         priceFeedFactory = PriceFeedFactory(_priceFeedFactory);
//     }

//     function createPriceFeed(
//         address owner,
//         uint8 decimals,
//         int initialAnswer
//     ) public returns (PriceFeedAggregator feed, ChainlinkPip chainlinkPipAddress) {
//         PriceFeedAggregator feed = new PriceFeedAggregator();

//         feed.file("decimals", uint(6));
//         feed.file("answer", tokenInfo.answer); // Feed Price);

//         // Transfer feed ownership to caller
//         feed.rely(owner);
//         feed.deny(address(this));
//     }

//     function createCollateralType(
//         CollateralParams memory params
//     ) public auth returns (CollateralInfo memory collateralAddresses) {
//         // require(!collaterals[params.ilk].exists, "CollateralTypeFactory/ilk-exists");

//         address token;
//         if (!params.isSelfManageToken) {
//             token = params.tokenAddress;
//         } else {
//             token = tokenFactory.createConfigurableToken(params.symbol, params.name, params.decimals, params.maxSupply);
//         }

//         if (!params.isSelfManagePriceFeed) {
//             revert("CollateralTypeFactory/chain-link-price-feed-not-supported");
//         }

//         (address aggregator, address pip) = priceFeedFactory.createPriceFeed(
//             8, // Fixed decimals
//             params.initialPrice,
//             "Self Manage Price Feed"
//         );

//         GemJoinLike join;
//         string memory ilkString = string(abi.encodePacked(params.symbol, "-A")); // PHP-A / USDC-A
//         bytes32 ilk = keccak256(bytes(ilkString));
//         if (params.decimals <= 6) {
//             join = GemJoinLike(address(new GemJoin5(address(vat), ilk, token)));
//         } else {
//             join = GemJoinLike(address(new GemJoin(address(vat), ilk, token)));
//         }

//         // TODO: linear decrease: auction price calculation mechanism

//         // Debt ceiling
//         proxyActions.file(address(vat), ilk, bytes32("line"), params.debtCeiling);
//         // Liquidation ratio
//         proxyActions.file(address(spotter), ilk, bytes32("mat"), params.liquidationRatio);
//         // todo: stability/liq penalty
//         // Ilk registry
//         ilkRegistry.add(address(join));
//     }
// }
