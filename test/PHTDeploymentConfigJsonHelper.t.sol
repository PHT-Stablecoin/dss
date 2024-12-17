pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {PHTDeploymentConfigJsonHelper, IPHTDeployConfigJson} from "./helpers/PHTDeploymentConfigJsonHelper.sol";

contract PHTDeploymentConfigJsonHelperTest is Test {
    address alice; // authority owner
    address eve; // authority root user
    address bob; // normal non-admin / "normal" user

    function test_readDeploymentConfig() public {
        PHTDeploymentConfigJsonHelper helper = new PHTDeploymentConfigJsonHelper();
        IPHTDeployConfigJson.Root memory root = helper.readDeploymentConfig("tests.json");

        assertEq(root.govTokenSymbol, "APC", "govTokenSymbol");
        assertEq(root.phtUsdFeed, address(0), "phtUsdFeed");
        assertEq(root.dogHoleRad, 10000000, "dogHoleRad");
        assertEq(root.vatLineRad, 10000000, "vatLineRad");
        assertEq(root.jugBase, 0.0000000006279e27, "jugBase");
        assertEq(root.authorityOwner, 0x328809Bc894f92807417D2dAD6b7C998c1aFdac6, "authorityOwner");
        assertEq(root.authorityRootUsers[0], 0xa959355654849CbEAbBf65235f8235833b9e031D, "authorityRootUsers[0]");
        assertEq(root.authorityRootUsers.length, 1, "authorityRootUsers.length");
    }
}
