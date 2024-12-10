pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import {StdCheatsSafe} from "forge-std/StdCheats.sol";
import {
    CommonLike,
    DssProxyActionsDsrLike,
    DssProxyActionsLike,
    DssProxyActionsEndLike
    } from "./interfaces/IDssProxyActions.sol";

import "./DssDeploy.t.base.pht.sol";

interface ProxyRegistryLike {
    function proxies(address) external view returns (address);
    function build(address) external returns (address);
}

interface ProxyLike {
    function owner() external view returns (address);
    function execute(address target, bytes memory data) external payable returns (bytes memory response);
}


contract DssDeployTestPHT is DssDeployTestBasePHT {
    DssProxy dssProxy;

    uint256 sepoliaFork;

    address SEPOLIA_CHAINLINK_DAI_USD = 0x14866185B1962B63C3Ea9E03Bc1da838bab34C19;
    address SEPOLIA_CHAINLINK_ETH_USD = 0x694AA1769357215DE4FAC081bf1f309aDC325306;

    PriceFeedAggregator phpUsdFeed;

    AggregatorV3Interface daiUsdFeed = AggregatorV3Interface(SEPOLIA_CHAINLINK_DAI_USD);
    AggregatorV3Interface ethUsdFeed = AggregatorV3Interface(SEPOLIA_CHAINLINK_ETH_USD);

    struct DssProxy {
        address Registry;
        address Actions;
        address ActionsDsr;
        address ActionsEnd;
    }

    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x, "sub-overflow");
    }

    function toInt(uint x) internal pure returns (int y) {
        y = int(x);
        require(y >= 0, "int-overflow");
    }

    function toRad(uint wad) internal pure returns (uint rad) {
        rad = mul(wad, 10 ** 27);
    }

    function setUp() public override {
        string memory SEPOLIA_RPC_URL = vm.envString("SEPOLIA_RPC_URL");
        sepoliaFork = vm.createFork(SEPOLIA_RPC_URL);
        vm.selectFork(sepoliaFork);

        super.setUp();

        dssProxy.Registry = StdCheatsSafe.deployCode("lib/dss-proxy/src/DssProxyRegistry.sol:DssProxyRegistry");
        dssProxy.Actions = StdCheatsSafe.deployCode("lib/dss-proxy-actions/src/DssProxyActions.sol:DssProxyActions");
        dssProxy.ActionsEnd = StdCheatsSafe.deployCode(
            "lib/dss-proxy-actions/src/DssProxyActions.sol:DssProxyActionsEnd"
        );
        dssProxy.ActionsDsr = StdCheatsSafe.deployCode(
            "lib/dss-proxy-actions/src/DssProxyActions.sol:DssProxyActionsDsr"
        );
    }

    function testaddCollateral_JointChainlink() public {
        deployKeepAuth(address(dssDeploy));
        
        (phpUsdFeed,) = feedFactory.create(8, int(0.0172e8), "PHP/USD");

        (
            ,
            PriceFeedAggregator feedDaiToPHT,
            ,
            ChainlinkPip pipTokenA
        ) = dssDeploy.addCollateral(
            proxyActions,
            ilkRegistry,
            DssDeployExt.IlkParams({
                ilk: "DAI-A",
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
                symbol: "pDAI",
                name: "pDAI",
                decimals: 18,
                maxSupply: 0
            }),
            DssDeployExt.FeedParams({
                factory: feedFactory,
                joinFactory: joinFeedFactory,
                feed: address(0),
                decimals: 0,
                initialPrice: int(0),
                numeratorFeed: address(daiUsdFeed),
                invertNumerator: false,
                denominatorFeed: address(phpUsdFeed),
                invertDenominator: false,
                feedDescription: "DAI/PHT"
            })
        );

        uint8 daiDecimals = daiUsdFeed.decimals();
        uint8 phpDecimals = phpUsdFeed.decimals();

        (, int256 answerDAI,,,) = daiUsdFeed.latestRoundData();
        (, int256 answerPHP,,,) = phpUsdFeed.latestRoundData();
        (, int256 answer,,,) = feedDaiToPHT.latestRoundData();

        assertApproxEqAbsDecimal(answer, 58e8, 5e8, 8, "1 DAI should be approx 58 PHT");
        
    }
}
