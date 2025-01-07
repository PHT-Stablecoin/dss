pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {DssDeploy, Clipper, Spotter} from "lib/dss-cdp-manager/lib/dss-deploy/src/DssDeploy.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {DSAuth, DSAuthority} from "ds-auth/auth.sol";
import {Jug} from "../src/jug.sol";

import {DSRoles} from "../pht/lib/Roles.sol";
import {PHTDeploy, PHTDeployResult} from "../script/PHTDeploy.sol";
import {PHTTokenHelper} from "../pht/PHTTokenHelper.sol";
import {FiatTokenInfo} from "../fiattoken/TokenTypes.sol";

import {PriceFeedFactory, PriceFeedAggregator} from "../pht/factory/PriceFeedFactory.sol";
import {PriceJoinFeedFactory, PriceJoinFeedAggregator} from "../pht/factory/PriceJoinFeedFactory.sol";
import {ChainlinkPip, AggregatorV3Interface, PipLike} from "../pht/helpers/ChainlinkPip.sol";
import {IlkRegistry} from "dss-ilk-registry/IlkRegistry.sol";

import {PHTDeployConfig} from "../script/PHTDeployConfig.sol";
import {ArrayHelpers} from "../pht/lib/ArrayHelpers.sol";

import {PHTCollateralTestLib} from "./helpers/PHTCollateralTestLib.sol";

contract PHTTokenHelperTest is Test {
    using ArrayHelpers for *;

    // --- Math ---
    uint256 constant WAD = 10 ** 18;
    uint256 constant RAY = 10 ** 27;
    uint256 constant RAD = 10 ** 45;

    address alice; // authority owner
    address eve; // authority root user
    PHTDeployResult res;
    PHTTokenHelper h;

    function setUp() public {
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
        h = PHTTokenHelper(res.tokenHelper);
    }

    function test_createToken() public {
        vm.startPrank(eve);
        
        (
            address implementation,
            address proxy,
            address masterMinter
        ) = h.createToken(
            PHTTokenHelper.TokenInfo({
                tokenName: "TEST",
                tokenSymbol: "TST",
                tokenDecimals: 18,
                tokenCurrency: "",
                initialSupply: 1000000e18,
                initialSupplyMintTo: eve // address to mint the initial supply to
            })
        );

        assertEq(h.tokenAddresses(h.lastToken()), proxy);
        assertEqDecimal(IERC20(proxy).balanceOf(eve), 1000000e18, 18);

    }

    function test_tokenHelper_mint() public {
        vm.startPrank(eve);
        (
            address implementation,
            address proxy,
            address masterMinter
        ) = h.createToken(
            PHTTokenHelper.TokenInfo({
                tokenName: "TEST",
                tokenSymbol: "TST",
                tokenDecimals: 18,
                tokenCurrency: "",
                initialSupply: 1000000e18,
                initialSupplyMintTo: eve // address to mint the initial supply to
            })
        );

        assertEq(h.tokenAddresses(h.lastToken()), proxy);

        h.mint(proxy, alice, 100e18);

        assertEqDecimal(IERC20(proxy).balanceOf(alice), 100e18, 18);
    }

    function test_tokenHelper_blacklist() public {
        vm.startPrank(eve);
        (
            address implementation,
            address proxy,
            address masterMinter
        ) = h.createToken(
            PHTTokenHelper.TokenInfo({
                tokenName: "TEST",
                tokenSymbol: "TST",
                tokenDecimals: 18,
                tokenCurrency: "",
                initialSupply: 1000000e18,
                initialSupplyMintTo: eve // address to mint the initial supply to
            })
        );

        assertEq(h.tokenAddresses(h.lastToken()), proxy);

        h.mint(proxy, alice, 100e18);
        assertEqDecimal(IERC20(proxy).balanceOf(alice), 100e18, 18);
        

        vm.startPrank(eve);
        h.blacklist(proxy, alice);
        {
            vm.startPrank(alice);
            vm.expectRevert("Blacklistable: account is blacklisted");
            IERC20(proxy).transfer(eve, 10e18);
            assertEqDecimal(IERC20(proxy).balanceOf(alice), 100e18, 18);
        }


        vm.startPrank(eve);
        h.unBlacklist(proxy, alice);
        {
            vm.startPrank(alice);
            IERC20(proxy).transfer(eve, 10e18);
            assertEqDecimal(IERC20(proxy).balanceOf(alice), 90e18, 18);
        }

    }

    function test_tokenHelper_transferOwnership() public {

        vm.startPrank(eve);
        (
            address implementation,
            address proxy,
            address masterMinter
        ) = h.createToken(
            PHTTokenHelper.TokenInfo({
                tokenName: "TEST",
                tokenSymbol: "TST",
                tokenDecimals: 18,
                tokenCurrency: "",
                initialSupply: 1000000e18,
                initialSupplyMintTo: eve // address to mint the initial supply to
            })
        );

        assertEq(h.tokenAddresses(h.lastToken()), proxy);

        h.mint(proxy, alice, 100e18);
        assertEqDecimal(IERC20(proxy).balanceOf(alice), 100e18, 18);

        PHTTokenHelper nh = new PHTTokenHelper(h.pause(), h.tokenFactory());
        h.transferMinterOwner(masterMinter, address(nh));
        nh.configureMinter(masterMinter);

        nh.mint(proxy, alice, 100e18);
        assertEqDecimal(IERC20(proxy).balanceOf(alice), 200e18, 18);
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
