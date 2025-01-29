pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {DSRoles} from "../pht/lib/Roles.sol";

import {DSPause} from "ds-pause/pause.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PHTDeploy, PHTDeployResult} from "../script/PHTDeploy.sol";
import {PHTTokenHelper, TokenActions, TokenInfo} from "../pht/PHTTokenHelper.sol";
import {PHTDeployConfig} from "../script/PHTDeployConfig.sol";
import {ArrayHelpers} from "../pht/lib/ArrayHelpers.sol";
import {PHTCollateralTestLib} from "./helpers/PHTCollateralTestLib.sol";
import {FiatTokenProxy} from "stablecoin-evm/v1/FiatTokenProxy.sol";

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
    PHTDeploy d;

    function setUp() public {
        eve = makeAddr("eve");
        alice = makeAddr("alice");
        d = new PHTDeploy();
        res = d.deploy(
            PHTDeployConfig({
                govTokenSymbol: "APC",
                phtUsdFeed: address(0), // deploy a mock feed for testing
                dogHoleRad: 10_000_000,
                vatLineRad: 10_000_000,
                jugBase: 0.0000000006279e27, // 0.00000006279% => 2% base global fee
                authorityOwner: alice,
                authorityRootUsers: [eve].toMemoryArray(),
                vowWaitSeconds: uint256(0),
                vowDumpWad: uint256(0),
                vowSumpRad: uint256(0),
                vowBumpRad: uint256(0),
                vowHumpRad: uint256(0)
            })
        );
        h = PHTTokenHelper(res.tokenHelper);
    }

    function test_createToken() public {
        vm.startPrank(eve);

        (address implementation, address proxy, address masterMinter) = h.createToken(
            TokenInfo({
                tokenName: "TEST",
                tokenSymbol: "TST",
                tokenDecimals: 18,
                tokenCurrency: "",
                initialSupply: 1000000e18,
                initialSupplyMintTo: eve, // address to mint the initial supply to
                tokenAdmin: alice
            })
        );

        assertEq(h.tokenAddresses(h.lastToken()), proxy);
        assertEq(FiatTokenProxy(payable(proxy)).admin(), alice);
        assertEqDecimal(IERC20(proxy).balanceOf(eve), 1000000e18, 18);
    }

    function test_tokenHelper_mint() public {
        vm.startPrank(eve);
        (address implementation, address proxy, address masterMinter) = h.createToken(
            TokenInfo({
                tokenName: "TEST",
                tokenSymbol: "TST",
                tokenDecimals: 18,
                tokenCurrency: "",
                initialSupply: 1000000e18,
                initialSupplyMintTo: eve, // address to mint the initial supply to
                tokenAdmin: address(1)
            })
        );

        assertEq(h.tokenAddresses(h.lastToken()), proxy);
        assertEq(FiatTokenProxy(payable(proxy)).admin(), address(1));

        h.mint(proxy, alice, 100e18);
        vm.stopPrank();

        vm.startPrank(alice);
        assertEqDecimal(IERC20(proxy).balanceOf(alice), 100e18, 18);
    }

    function test_tokenHelper_blacklist() public {
        vm.startPrank(eve);
        (address implementation, address proxy, address masterMinter) = h.createToken(
            TokenInfo({
                tokenName: "TEST",
                tokenSymbol: "TST",
                tokenDecimals: 18,
                tokenCurrency: "",
                initialSupply: 1000000e18,
                initialSupplyMintTo: eve, // address to mint the initial supply to
                tokenAdmin: address(1)
            })
        );
        assertEq(h.tokenAddresses(h.lastToken()), proxy);
        h.mint(proxy, alice, 100e18);
        assertEqDecimal(IERC20(proxy).balanceOf(alice), 100e18, 18);
        h.blacklist(proxy, alice);
        vm.stopPrank();

        {
            vm.startPrank(alice);
            vm.expectRevert("Blacklistable: account is blacklisted");
            IERC20(proxy).transfer(eve, 10e18);
            assertEqDecimal(IERC20(proxy).balanceOf(alice), 100e18, 18);
            vm.stopPrank();
        }

        vm.prank(eve);
        h.unBlacklist(proxy, alice);
        {
            vm.startPrank(alice);
            IERC20(proxy).transfer(eve, 10e18);
            assertEqDecimal(IERC20(proxy).balanceOf(alice), 90e18, 18);
            vm.stopPrank();
        }
    }

    function test_tokenHelper_new_helper() public {
        vm.startPrank(eve);
        (address implementation, address proxy, address masterMinter) = h.createToken(
            TokenInfo({
                tokenName: "TEST",
                tokenSymbol: "TST",
                tokenDecimals: 18,
                tokenCurrency: "",
                initialSupply: 1000000e18,
                initialSupplyMintTo: eve, // address to mint the initial supply to
                tokenAdmin: address(1)
            })
        );

        assertEq(h.tokenAddresses(h.lastToken()), proxy);

        h.mint(proxy, alice, 100e18);
        assertEqDecimal(IERC20(proxy).balanceOf(alice), 100e18, 18);

        PHTTokenHelper nh = new PHTTokenHelper(h.pause(), new TokenActions(), h.tokenFactory());

        {
            vm.startPrank(alice);
            DSRoles(address(res.authority)).setUserRole(address(nh), d.ROLE_CAN_PLOT(), true);
            vm.stopPrank();
        }

        vm.startPrank(eve);
        nh.mint(proxy, alice, 100e18);
        assertEqDecimal(IERC20(proxy).balanceOf(alice), 200e18, 18);
    }
}
