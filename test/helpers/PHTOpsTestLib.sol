pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import {PHTDeployResult} from "../../script/PHTDeploy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Vat} from "dss/vat.sol";
import {DssCdpManager} from "dss-cdp-manager/DssCdpManager.sol";
import {ProxyRegistryLike, ProxyLike, DssProxyActionsLike} from "../../script/PHTDeploy.sol";

library PHTOpsTestLib {
    function openLockGemAndDraw(PHTDeployResult memory res, address user, bytes32 ilk, address token, address join)
        internal
    {
        address proxy = ProxyRegistryLike(res.dssProxyRegistry).build(user);
        // user approves the proxy to spend his tokens
        IERC20(token).approve(address(proxy), 1000 * 10 ** 6);
        // Call openLockGemAndDraw with correct amtC
        uint256 cdpId = abi.decode(
            ProxyLike(proxy).execute(
                address(res.dssProxyActions),
                abi.encodeWithSelector(
                    DssProxyActionsLike.openLockGemAndDraw.selector,
                    res.dssCdpManager,
                    res.jug,
                    join,
                    res.daiJoin,
                    ilk,
                    uint256(1.06e6),
                    uint256(1e18), // Drawing 1 DAI (18 decimals)
                    true
                )
            ),
            (uint256)
        );

        // Collateral owned by Join
        require(IERC20(token).balanceOf(address(join)) == 1.06e6, "Collateral owned by Join");
        // After operation, balance should be zero
        require(Vat(res.vat).gem(ilk, address(proxy)) == 0, "After operation, balance should be zero");
        // Collateral owned by cdpId also zero
        require(
            Vat(res.vat).gem(ilk, DssCdpManager(res.dssCdpManager).urns(cdpId)) == 0,
            "Collateral owned by cdpId also zero"
        );

        require(IERC20(res.dai).balanceOf(user) == 1e18, "Dai (PHT) is transferred to bob");
        // Gem ownership in urnhandler
        require(Vat(res.vat).gem(ilk, address(this)) == 0, "Gem ownership in urnhandler");
    }
}
