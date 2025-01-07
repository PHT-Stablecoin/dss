pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "dss-deploy/DssDeploy.sol";
import {DssCdpManager} from "dss-cdp-manager/DssCdpManager.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Vat} from "../src/vat.sol";
import {PHTDeploy, PHTDeployResult, ProxyLike, ProxyRegistryLike, DssProxyActionsLike} from "../script/PHTDeploy.sol";
import {Jug} from "../src/jug.sol";
import {PHTDeployConfig} from "../script/PHTDeployConfig.sol";
import {PHTCollateralHelper} from "../pht/PHTCollateralHelper.sol";
import {ArrayHelpers} from "../pht/lib/ArrayHelpers.sol";
import {DSRoles} from "../pht/lib/Roles.sol";
import {ProxyActions} from "../pht/helpers/ProxyActions.sol";
import {PHTCollateralTestLib} from "./helpers/PHTCollateralTestLib.sol";
import {PHTTokenHelper} from "../pht/PHTTokenHelper.sol";

import {PHTOpsTestLib} from "./helpers/PHTOpsTestLib.sol";

import {FiatTokenFactory} from "../fiattoken/FiatTokenFactory.sol";
import {FiatTokenInfo} from "../fiattoken/TokenTypes.sol";
import {MinterManagementInterface} from "stablecoin-evm/minting/MinterManagementInterface.sol";

contract PHTDeployIntegrationTest is Test {
    using ArrayHelpers for *;

    // --- Math ---
    uint256 constant RAD = 10 ** 45;

    // --- Constants ---
    bytes32 constant ILK_NAME = bytes32("PHP-A");

    address alice; // authority owner
    address eve; // authority root user
    address bob; // normal non-admin / "normal" user

    function _deploy() internal returns (PHTDeploy d, PHTCollateralHelper h, PHTDeployResult memory res) {
        d = new PHTDeploy();
        eve = makeAddr("eve");
        alice = makeAddr("alice");
        bob = makeAddr("bob");

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
        return (d, h, res);
    }

    function test_stableEvmDeploy() public {
        (PHTDeploy d, PHTCollateralHelper h, PHTDeployResult memory res) = _deploy();
        assertTrue(res.tokenFactory != address(0), "tokenFactory should be non-zero");

        // Create addresses for different roles
        address proxyAdmin = makeAddr("proxyAdmin");
        address owner = makeAddr("owner");
        address masterMinterOwner = makeAddr("masterMinterOwner");
        address controller = makeAddr("controller");
        address minter = makeAddr("minter");

        // Test #1: Create a token
        PHTTokenHelper.TokenInfo memory info = PHTTokenHelper.TokenInfo({
            tokenName: "Stable1",
            tokenSymbol: "ST1",
            tokenDecimals: 6,
            tokenCurrency: "USD",
            initialSupply: 100_000 * 1e6,
            initialSupplyMintTo: bob
        });

        vm.startPrank(eve);
        (address implementation, address proxy, address masterMinter) =
            PHTTokenHelper(res.tokenHelper).createToken(info);

        // Verify initial balance
        assertEq(IERC20(proxy).balanceOf(bob), 100_000 * 1e6, "bob should have 100,000 tokens");
        PHTTokenHelper(res.tokenHelper).mint(proxy, bob, 1e9);
        assertEq(IERC20(proxy).balanceOf(bob), (100_000 * 1e6) + 1e9, "bob should have 100,000 + 1000 tokens");
        vm.stopPrank();
    }

    function test_openLockGemAndDraw() public {
        (PHTDeploy d, PHTCollateralHelper h, PHTDeployResult memory res) = _deploy();
        vm.startPrank(eve);
        (address join,, address token,) = PHTCollateralTestLib.addCollateral(bytes32(ILK_NAME), res, h, eve);
        // transfer some tokens to bob
        IERC20(token).transfer(bob, 1e9);

        uint256 jugBase = Jug(res.jug).base();
        uint256 jugRate = Jug(res.jug).drip(ILK_NAME);
        assertGt(jugBase, 0, "jugBase is not zero");
        assertGt(jugRate, 0, "jugRate is not zero");

        // Move Blocktime to 10 blocks ahead
        vm.warp(now + 100);

        // normal user opens a CDP
        vm.startPrank(bob);
        PHTOpsTestLib.openLockGemAndDraw(res, bob, ILK_NAME, token, join);
        vm.stopPrank();
    }
}

interface DsPauseLike {
    function plot(address, bytes32, bytes calldata, uint256) external;
    function drop(address, bytes32, bytes calldata, uint256) external;
    function exec(address, bytes32, bytes calldata, uint256) external returns (bytes memory);
}

interface IHasWards {
    function wards(address) external view returns (uint256);
}

interface IHasProxy {
    function proxy() external view returns (address);
}

interface IFiatToken {
    function mint(address _to, uint256 _amount) external returns (bool);
    function masterMinter() external view returns (address);
}

interface IMasterMinter {
    function configureController(address controller, address worker) external;
    function configureMinter(uint256 minterAllowedAmount) external returns (bool);
}

interface IMintController {
    function configureMinter(uint256 minterAllowedAmount) external returns (bool);
    function getMinterManager() external view returns (MinterManagementInterface);
}
