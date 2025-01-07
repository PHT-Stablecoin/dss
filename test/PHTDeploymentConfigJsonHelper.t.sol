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

        assertEq(
            root._notes,
            "The _notes field is used to store any additional information about the configuration. It is not used for any other purpose.",
            "_notes"
        );

        assertEq(root.authorityOwner, 0x328809Bc894f92807417D2dAD6b7C998c1aFdac6, "authorityOwner");
        assertEq(root.authorityRootUsers.length, 4, "authorityRootUsers.length");
        assertEq(root.authorityRootUsers[0], 0x328809Bc894f92807417D2dAD6b7C998c1aFdac6, "authorityRootUsers[0]");
        assertEq(root.authorityRootUsers[1], 0xa959355654849CbEAbBf65235f8235833b9e031D, "authorityRootUsers[1]");
        assertEq(root.authorityRootUsers[2], 0x1111111111111111111111111111111111111111, "authorityRootUsers[2]");
        assertEq(root.authorityRootUsers[3], 0xfEEDFEEDfeEDFEedFEEdFEEDFeEdfEEdFeEdFEEd, "authorityRootUsers[3]");
        assertEq(root.dogHoleRad, 10000000, "dogHoleRad");
        assertEq(root.govTokenSymbol, "APC", "govTokenSymbol");
        assertEq(root.jugBase, 0.0000000006279e27, "jugBase");
        assertEq(root.phtUsdFeed, 0xfEEDFEEDfeEDFEedFEEdFEEDFeEdfEEdFeEdFEEd, "phtUsdFeed");
        assertEq(root.vatLineRad, 13000000, "vatLineRad");

        assertEq(root.collaterals.length, 1, "collaterals.length");
        IPHTDeployConfigJson.Collateral memory collateral = root.collaterals[0];
        IPHTDeployConfigJson.FeedParams memory feedParams = collateral.feedParams;
        IPHTDeployConfigJson.IlkParams memory ilkParams = collateral.ilkParams;
        IPHTDeployConfigJson.TokenParams memory tokenParams = collateral.tokenParams;

        assertEq(uint256(feedParams.decimals), 6, "feedParams.decimals");
        assertEq(feedParams.denominatorFeed, 0x1111111111111111111111111111111111111111, "feedParams.denominatorFeed");
        assertEq(feedParams.feed, 0xfEEDFEEDfeEDFEedFEEdFEEDFeEdfEEdFeEdFEEd, "feedParams.feed");
        assertEq(feedParams.feedDescription, "Test feed", "feedParams.feedDescription");
        assertEq(uint256(feedParams.initialPrice), 1000000, "feedParams.initialPrice");
        assertEq(feedParams.invertDenominator, true, "feedParams.invertDenominator");
        assertEq(feedParams.invertNumerator, false, "feedParams.invertNumerator");
        assertEq(feedParams.numeratorFeed, 0x2222222222222222222222222222222222222222, "feedParams.numeratorFeed");

        assertEq(ilkParams.buf, 1.2e27, "ilkParams.buf");
        assertEq(ilkParams.chop, 1.13e18, "ilkParams.chop");
        assertEq(ilkParams.dust, 11, "ilkParams.dust");
        assertEq(ilkParams.duty, 1.0000000012436807e27, "ilkParams.duty");
        assertEq(ilkParams.holeRad, 5000000, "ilkParams.holeRad");
        assertEq(bytes32(ilkParams.ilk), bytes32("PHP-A"), "ilkParams.ilk");
        assertEq(ilkParams.lineRad, 5000000, "ilkParams.lineRad");
        assertEq(ilkParams.matEther, 1050000000, "ilkParams.matEther");
        assertEq(ilkParams.tau, 3600, "ilkParams.tau");

        assertEq(uint256(tokenParams.decimals), 6, "tokenParams.decimals");
        assertEq(tokenParams.initialSupply, 1000000000, "tokenParams.initialSupply");
        assertEq(tokenParams.maxSupply, 333, "tokenParams.maxSupply");
        assertEq(tokenParams.name, "Testtttttttt PHP", "tokenParams.name");
        assertEq(tokenParams.symbol, "tstPHP", "tokenParams.symbol");
        assertEq(tokenParams.token, 0x70ce70CE70Ce70Ce70Ce70cE70CE70Ce70Ce70ce, "tokenParams.token");
    }
}
