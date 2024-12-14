pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {DssDeploy, Clipper} from "lib/dss-cdp-manager/lib/dss-deploy/src/DssDeploy.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {DSAuth, DSAuthority} from "ds-auth/auth.sol";

import {DSRoles} from "../pht/lib/Roles.sol";
import {PHTDeploy, PHTDeployResult} from "../pht/PHTDeploy.sol";
import {PHTCollateralHelper} from "../pht/PHTCollateralHelper.sol";
import {PriceFeedFactory, PriceFeedAggregator} from "../pht/factory/PriceFeedFactory.sol";
import {PriceJoinFeedFactory, PriceJoinFeedAggregator} from "../pht/factory/PriceJoinFeedFactory.sol";
import {ChainlinkPip, AggregatorV3Interface} from "../pht/helpers/ChainlinkPip.sol";
import {IlkRegistry} from "dss-ilk-registry/IlkRegistry.sol";

import {PHTDeployConfig, PHTDeployCollateralConfig} from "../pht/PHTDeployConfig.sol";
import {ArrayHelpers} from "../pht/lib/ArrayHelpers.sol";

import {PHTCollateralTestLib} from "./helpers/PHTCollateralTestLib.sol";

contract PHTCollateralHelperTest is Test {
    using ArrayHelpers for *;

    // --- Math ---
    uint256 constant WAD = 10 ** 18;
    uint256 constant RAY = 10 ** 27;
    uint256 constant RAD = 10 ** 45;

    // -- ROLES --
    uint8 constant ROLE_GOV_MINT_BURN = 10;
    uint8 constant ROLE_CAN_PLOT = 11;

    address alice; // authority owner
    address eve; // authority root user
    PHTDeployResult res;
    PHTCollateralHelper h;

    function setUp() public {
        eve = makeAddr("eve");
        alice = makeAddr("alice");
        PHTDeployCollateralConfig[] memory collateralConfigs = new PHTDeployCollateralConfig[](0);
        PHTDeploy d = new PHTDeploy();
        res = d.deploy(
            PHTDeployConfig({
                govTokenSymbol: "APC",
                dogHoleRad: 10_000_000,
                vatLineRad: 10_000_000,
                jugBase: 0.0000000006279e27, // 0.00000006279% => 2% base global fee
                authorityOwner: alice,
                authorityRootUsers: [eve].toMemoryArray(),
                collateralConfigs: collateralConfigs
            })
        );
        h = PHTCollateralHelper(res.collateralHelper);
    }

    function test_addsIlk() public {
        uint256 ilksCountBef = IlkRegistry(res.ilkRegistry).count();

        vm.startPrank(eve);
        (address phpJoin, AggregatorV3Interface feed, address token, ChainlinkPip pip) = PHTCollateralTestLib
            .addCollateral(res, h, eve);
        vm.stopPrank();

        assertEq(IERC20Metadata(token).name(), "Test PHP", "token name");
        assertEq(IERC20Metadata(token).symbol(), "tstPHP", "token symbol");
        assertEq(uint256(IERC20Metadata(token).decimals()), 6, "token decimals");
        // ensure eve received the token balance
        assertEq(IERC20(token).balanceOf(eve), 1000 * 10 ** 6, "eve should have received the token balance");
        assertEq(IlkRegistry(res.ilkRegistry).count(), ilksCountBef + 1, "[PHTCollateralHelperTest] ilksCount");
        assertEq(bytes32("PHP-A"), IlkRegistry(res.ilkRegistry).list()[ilksCountBef], "[PHTCollateralHelperTest] ilk");
    }

    function test_shouldFailWithAuth() public {
        vm.expectRevert("ds-auth-unauthorized");
        PHTCollateralTestLib.addCollateral(res, h, alice);
    }

    function test_rootCanAddCollateral() public {
        vm.startPrank(eve);
        PHTCollateralTestLib.addCollateral(res, h, eve);
        vm.stopPrank();
    }

    function test_ownerCannotAddCollateral() public {
        vm.startPrank(alice);
        vm.expectRevert("ds-auth-unauthorized");
        PHTCollateralTestLib.addCollateral(res, h, alice);
        vm.stopPrank();
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
