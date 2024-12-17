pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "forge-std/StdCheats.sol";


import {ArrayHelpers} from "../pht/lib/ArrayHelpers.sol";
import "../script/PHTDeploy.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ITokenFactory} from "../../fiattoken/FiatTokenFactory.sol";

contract DssDeployTestPHT is Test {
    using ArrayHelpers for *;

    // --- Math ---
    uint256 constant WAD = 10 ** 18;
    uint256 constant RAY = 10 ** 27;
    uint256 constant RAD = 10 ** 45;

    // --- CONSTANTS ---
    string constant ILK_PREFIX = "PHT-NEW-ILK-";

    // -- ROLES --
    uint8 constant ROLE_GOV_MINT_BURN = 10;
    uint8 constant ROLE_CAN_PLOT = 11;

    address alice; // authority owner
    address eve; // authority root user
    PHTDeployResult res;
    PHTCollateralHelper h;

    uint256 sepoliaFork;

    address SEPOLIA_CHAINLINK_DAI_USD = 0x14866185B1962B63C3Ea9E03Bc1da838bab34C19;
    address SEPOLIA_CHAINLINK_ETH_USD = 0x694AA1769357215DE4FAC081bf1f309aDC325306;

    PriceFeedAggregator phpUsdFeed;

    AggregatorV3Interface daiUsdFeed = AggregatorV3Interface(SEPOLIA_CHAINLINK_DAI_USD);
    AggregatorV3Interface ethUsdFeed = AggregatorV3Interface(SEPOLIA_CHAINLINK_ETH_USD);

    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x, "sub-overflow");
    }

    function toInt(uint x) internal pure returns (int y) {
        y = int(x);
        require(y >= 0, "int-overflow");
    }

    function setUp() public {
        string memory SEPOLIA_RPC_URL = vm.envString("SEPOLIA_RPC_URL");
        sepoliaFork = vm.createFork(SEPOLIA_RPC_URL);
        vm.selectFork(sepoliaFork);

        eve = makeAddr("eve");
        alice = makeAddr("alice");
        PHTDeploy d = new PHTDeploy();
        res = d.deploy(
            PHTDeployConfig({
                govTokenSymbol: "APC",
                phtUsdFeed: address(0), // deploy a mock feed for testing
                dogHoleRad: 10_000_000,
                vatLineRad: 10_000_000,
                jugBase: 0.0000000006279e27, // 0.00000006279% => 2% base global fee
                authorityOwner: alice,
                authorityRootUsers: [eve].toMemoryArray()
            })
        );
        h = PHTCollateralHelper(res.collateralHelper);

        phpUsdFeed = PriceFeedFactory(res.priceFeedFactory).create(8, int(0.0172e8), "PHP/USD");

    }

    function testaddCollateral_JointChainlink() public {        
         uint256 ilksCountBef = IlkRegistry(res.ilkRegistry).count();

        vm.startPrank(eve);
        bytes32 ilk = "pDAI";

        (
            ,
            AggregatorV3Interface feedDaiToPHT,
            address token,
            ChainlinkPip pip
        ) = PHTCollateralHelper(res.collateralHelper).addCollateral(
            res.proxyActions,
            res.ilkRegistry,
            PHTCollateralHelper.IlkParams({
                ilk: ilk,
                line: uint(10000 * 10 ** 45),
                dust: uint(0),
                tau: 1 hours,
                mat: uint(1500000000 ether), // mat: Liquidation Ratio (150%),
                hole: 5_000_000 * RAD, // Set DAI-A limit to 5 million DAI (RAD units)
                chop: 1.13e18, // Set the liquidation penalty (chop) for "DAI-A" to 13% (1.13e18 in WAD units)
                buf: 1.20e27, // Set a 20% increase in auctions (RAY)
                duty: 1.0000000018477e27 // 0.00000018477% => 6% Annual duty
            }),
            PHTCollateralHelper.TokenParams({
                token: address(0),
                factory: ITokenFactory(res.tokenFactory),
                symbol: "pDAI",
                name: "pDAI",
                decimals: 18,
                maxSupply: 0,
                initialSupply: 1000e18
            }),
            PHTCollateralHelper.FeedParams({
                factory: PriceFeedFactory(res.priceFeedFactory),
                joinFactory: PriceJoinFeedFactory(res.joinFeedFactory),
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
        vm.stopPrank();

        
        assertEq(IERC20Metadata(token).name(), "pDAI", "token name");
        assertEq(IERC20Metadata(token).symbol(), "pDAI", "token symbol");
        assertEq(uint256(IERC20Metadata(token).decimals()), 18, "token decimals");

        assertEq(IERC20(token).balanceOf(eve), 1000 * 10 ** 18, "eve should have received the token balance");
        assertEq(IlkRegistry(res.ilkRegistry).count(), ilksCountBef + 1, "[PHTCollateralHelperTest] ilksCount");
        assertEq(address(pip), IlkRegistry(res.ilkRegistry).pip(ilk), "Same Pip");

        (bytes32 answer,) = pip.peek();
        assertApproxEqAbsDecimal(uint256(answer), 58e18, 0.2e18, 18, "1 DAI should be approx 58 PHT");
        
    }
}

interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}