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

        assertEq(root.collaterals.length, 2, "collaterals.length");
        IPHTDeployConfigJson.Collateral memory collateral0 = root.collaterals[0];
        IPHTDeployConfigJson.FeedParams memory feedParams0 = collateral0.feedParams;
        IPHTDeployConfigJson.IlkParams memory ilkParams0 = collateral0.ilkParams;
        IPHTDeployConfigJson.TokenParams memory tokenParams0 = collateral0.tokenParams;

        assertEq(uint256(feedParams0.decimals), 6, "feedParams0.decimals");
        assertEq(feedParams0.denominatorFeed, 0x1111111111111111111111111111111111111111, "feedParams0.denominatorFeed");
        assertEq(feedParams0.feed, 0xfEEDFEEDfeEDFEedFEEdFEEDFeEdfEEdFeEdFEEd, "feedParams0.feed");
        assertEq(feedParams0.feedDescription, "Test feed", "feedParams0.feedDescription");
        assertEq(uint256(feedParams0.initialPrice), 1000000, "feedParams0.initialPrice");
        assertEq(feedParams0.invertDenominator, true, "feedParams0.invertDenominator");
        assertEq(feedParams0.invertNumerator, false, "feedParams0.invertNumerator");
        assertEq(feedParams0.numeratorFeed, 0x2222222222222222222222222222222222222222, "feedParams0.numeratorFeed");

        assertEq(ilkParams0.buf, 1.2e27, "ilkParams0.buf");
        assertEq(ilkParams0.chop, 1.13e18, "ilkParams0.chop");
        assertEq(ilkParams0.dust, 11, "ilkParams0.dust");
        assertEq(ilkParams0.duty, 1.0000000012436807e27, "ilkParams0.duty");
        assertEq(ilkParams0.holeRad, 5000000, "ilkParams0.holeRad");
        assertEq(bytes32(ilkParams0.ilk), bytes32("PHP-A"), "ilkParams0.ilk");
        assertEq(ilkParams0.lineRad, 5000000, "ilkParams0.lineRad");
        assertEq(ilkParams0.matEther, 1050000000, "ilkParams0.matEther");
        assertEq(ilkParams0.tau, 3600, "ilkParams0.tau");

        assertEq(uint256(tokenParams0.decimals), 6, "tokenParams0.decimals");
        assertEq(tokenParams0.initialSupply, 1000000000, "tokenParams0.initialSupply");
        assertEq(tokenParams0.maxSupply, 333, "tokenParams0.maxSupply");
        assertEq(tokenParams0.name, "Testtttttttt PHP", "tokenParams0.name");
        assertEq(tokenParams0.symbol, "tstPHP", "tokenParams0.symbol");
        assertEq(tokenParams0.token, 0x70ce70CE70Ce70Ce70Ce70cE70CE70Ce70Ce70ce, "tokenParams0.token");

        IPHTDeployConfigJson.Collateral memory collateral1 = root.collaterals[1];
        IPHTDeployConfigJson.FeedParams memory feedParams1 = collateral1.feedParams;
        IPHTDeployConfigJson.IlkParams memory ilkParams1 = collateral1.ilkParams;
        IPHTDeployConfigJson.TokenParams memory tokenParams1 = collateral1.tokenParams;

        assertEq(uint256(feedParams1.decimals), 9, "feedParams1.decimals");
        assertEq(feedParams1.denominatorFeed, 0x2111111111111111111111111111111111111111, "feedParams1.denominatorFeed");
        assertEq(feedParams1.feed, 0xfEEDFEEDfeEDFEedFEEdFEEDFeEdfEEdFeEdFEEd, "feedParams1.feed");
        assertEq(feedParams1.feedDescription, "Test feed2", "feedParams1.feedDescription");
        assertEq(uint256(feedParams1.initialPrice), 2000000, "feedParams1.initialPrice");
        assertEq(feedParams1.invertDenominator, false, "feedParams1.invertDenominator");
        assertEq(feedParams1.invertNumerator, true, "feedParams1.invertNumerator");
        assertEq(feedParams1.numeratorFeed, 0x3222222222222222222222222222222222222222, "feedParams1.numeratorFeed");

        assertEq(ilkParams1.buf, 2.2e27, "ilkParams1.buf");
        assertEq(ilkParams1.chop, 2.13e18, "ilkParams1.chop");
        assertEq(ilkParams1.dust, 12, "ilkParams1.dust");
        assertEq(ilkParams1.duty, 2.0000000012436807e27, "ilkParams1.duty");
        assertEq(ilkParams1.holeRad, 6000000, "ilkParams1.holeRad");
        assertEq(bytes32(ilkParams1.ilk), bytes32("PHP-B"), "ilkParams1.ilk");
        assertEq(ilkParams1.lineRad, 6000000, "ilkParams1.lineRad");
        assertEq(ilkParams1.matEther, 2050000000, "ilkParams1.matEther");
        assertEq(ilkParams1.tau, 4600, "ilkParams1.tau");

        assertEq(uint256(tokenParams1.decimals), 7, "tokenParams1.decimals");
        assertEq(tokenParams1.initialSupply, 2000000000, "tokenParams1.initialSupply");
        assertEq(tokenParams1.maxSupply, 666, "tokenParams1.maxSupply");
        assertEq(tokenParams1.name, "Testtttttttt PHP2", "tokenParams1.name");
        assertEq(tokenParams1.symbol, "tstPHP2", "tokenParams1.symbol");
        assertEq(tokenParams1.token, 0x80cE70Ce70ce70cE70Ce70CE70cE70cE70Ce70CE, "tokenParams1.token");
    }
}
