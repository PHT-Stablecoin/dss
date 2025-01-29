pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import {DSPause} from "ds-pause/pause.sol";
import {DSAuth} from "ds-auth/auth.sol";
import {GovActions} from "dss-deploy/govActions.sol";
import {DSAuthority} from "ds-auth/auth.sol";

struct DelayedAction {
    address usr;
    bytes32 tag;
    uint256 eta;
    bytes fax;
}

// @TODO move this behind a TransparentUpgradeableProxy

contract ProxyActions is DSAuth {
    DSPause public pause;
    GovActions public govActions;

    constructor(address _pause, address _govActions) public {
        require(address(_pause) != address(0), "ProxyActions/pause-not-set");
        require(address(_govActions) != address(0), "ProxyActions/govActions-not-set");

        pause = DSPause(_pause);
        govActions = GovActions(_govActions);
        authority = DSAuthority(address(pause.authority()));
    }

    function rely(address from, address to) external auth returns (DelayedAction memory a) {
        address usr = address(govActions);
        bytes32 tag;
        assembly {
            tag := extcodehash(usr)
        }
        bytes memory fax = abi.encodeWithSignature("rely(address,address)", from, to);
        uint256 delay = pause.delay();
        uint256 eta = now + delay;

        pause.plot(usr, tag, fax, eta);
        if (delay == 0) pause.exec(usr, tag, fax, eta);

        return DelayedAction(usr, tag, eta, fax);
    }

    function deny(address from, address to) external auth returns (DelayedAction memory action) {
        address usr = address(govActions);
        bytes32 tag;
        assembly {
            tag := extcodehash(usr)
        }
        bytes memory fax = abi.encodeWithSignature("deny(address,address)", from, to);
        uint256 delay = pause.delay();
        uint256 eta = now + delay;

        pause.plot(usr, tag, fax, eta);
        if (delay == 0) pause.exec(usr, tag, fax, eta);

        return DelayedAction(usr, tag, eta, fax);
    }

    function init(address who, bytes32 ilk) external auth returns (DelayedAction memory action) {
        address usr = address(govActions);
        bytes32 tag;
        assembly {
            tag := extcodehash(usr)
        }
        bytes memory fax = abi.encodeWithSignature("init(address,bytes32)", who, ilk);
        uint256 delay = pause.delay();
        uint256 eta = now + delay;

        pause.plot(usr, tag, fax, eta);
        if (delay == 0) pause.exec(usr, tag, fax, eta);

        return DelayedAction(usr, tag, eta, fax);
    }

    function file(address who, bytes32 what, uint256 data) external auth returns (DelayedAction memory action) {
        address usr = address(govActions);
        bytes32 tag;
        assembly {
            tag := extcodehash(usr)
        }
        bytes memory fax = abi.encodeWithSignature("file(address,bytes32,uint256)", who, what, data);
        uint256 delay = pause.delay();
        uint256 eta = now + delay;

        pause.plot(usr, tag, fax, eta);
        if (delay == 0) pause.exec(usr, tag, fax, eta);

        return DelayedAction(usr, tag, eta, fax);
    }

    function file(address who, bytes32 what, address data) external auth returns (DelayedAction memory action) {
        address usr = address(govActions);
        bytes32 tag;
        assembly {
            tag := extcodehash(usr)
        }
        bytes memory fax = abi.encodeWithSignature("file(address,bytes32,address)", who, what, data);
        uint256 delay = pause.delay();
        uint256 eta = now + delay;

        pause.plot(usr, tag, fax, eta);
        if (delay == 0) pause.exec(usr, tag, fax, eta);

        return DelayedAction(usr, tag, eta, fax);
    }

    function file(address who, bytes32 ilk, bytes32 what, uint256 data)
        external
        auth
        returns (DelayedAction memory action)
    {
        address usr = address(govActions);
        bytes32 tag;
        assembly {
            tag := extcodehash(usr)
        }
        bytes memory fax = abi.encodeWithSignature("file(address,bytes32,bytes32,uint256)", who, ilk, what, data);
        uint256 delay = pause.delay();
        uint256 eta = now + delay;

        pause.plot(usr, tag, fax, eta);
        if (delay == 0) pause.exec(usr, tag, fax, eta);

        return DelayedAction(usr, tag, eta, fax);
    }

    function file(address who, bytes32 ilk, bytes32 what, address data)
        external
        auth
        returns (DelayedAction memory action)
    {
        address usr = address(govActions);
        bytes32 tag;
        assembly {
            tag := extcodehash(usr)
        }
        bytes memory fax = abi.encodeWithSignature("file(address,bytes32,bytes32,address)", who, ilk, what, data);
        uint256 delay = pause.delay();
        uint256 eta = now + delay;

        pause.plot(usr, tag, fax, eta);
        if (delay == 0) pause.exec(usr, tag, fax, eta);

        return DelayedAction(usr, tag, eta, fax);
    }

    function dripAndFile(address who, bytes32 what, uint256 data) external auth returns (DelayedAction memory action) {
        address usr = address(govActions);
        bytes32 tag;
        assembly {
            tag := extcodehash(usr)
        }
        bytes memory fax = abi.encodeWithSignature("dripAndFile(address,bytes32,uint256)", who, what, data);
        uint256 delay = pause.delay();
        uint256 eta = now + delay;

        pause.plot(usr, tag, fax, eta);
        if (delay == 0) pause.exec(usr, tag, fax, eta);

        return DelayedAction(usr, tag, eta, fax);
    }

    function dripAndFile(address who, bytes32 ilk, bytes32 what, uint256 data)
        external
        auth
        returns (DelayedAction memory action)
    {
        address usr = address(govActions);
        bytes32 tag;
        assembly {
            tag := extcodehash(usr)
        }
        bytes memory fax = abi.encodeWithSignature("dripAndFile(address,bytes32,bytes32,uint256)", who, ilk, what, data);
        uint256 delay = pause.delay();
        uint256 eta = now + delay;

        pause.plot(usr, tag, fax, eta);
        if (delay == 0) pause.exec(usr, tag, fax, eta);

        return DelayedAction(usr, tag, eta, fax);
    }

    function cage(address end) external auth returns (DelayedAction memory action) {
        address usr = address(govActions);
        bytes32 tag;
        assembly {
            tag := extcodehash(usr)
        }
        bytes memory fax = abi.encodeWithSignature("cage(address)", end);
        uint256 delay = pause.delay();
        uint256 eta = now + delay;

        pause.plot(usr, tag, fax, eta);
        if (delay == 0) pause.exec(usr, tag, fax, eta);

        return DelayedAction(usr, tag, eta, fax);
    }

    function setAuthority2(address newAuthority) external auth returns (DelayedAction memory action) {
        address usr = address(govActions);
        bytes32 tag;
        assembly {
            tag := extcodehash(usr)
        }
        bytes memory fax = abi.encodeWithSignature("setAuthority(address,address)", pause, newAuthority);
        uint256 delay = pause.delay();
        uint256 eta = now + delay;

        pause.plot(usr, tag, fax, eta);
        if (delay == 0) pause.exec(usr, tag, fax, eta);

        return DelayedAction(usr, tag, eta, fax);
    }

    function setDelay(uint256 newDelay) external auth returns (DelayedAction memory action) {
        address usr = address(govActions);
        bytes32 tag;
        assembly {
            tag := extcodehash(usr)
        }
        bytes memory fax = abi.encodeWithSignature("setDelay(address,uint256)", pause, newDelay);
        uint256 delay = pause.delay();
        uint256 eta = now + delay;

        pause.plot(usr, tag, fax, eta);
        if (delay == 0) pause.exec(usr, tag, fax, eta);

        return DelayedAction(usr, tag, eta, fax);
    }

    function setAuthorityAndDelay(address newAuthority, uint256 newDelay)
        external
        auth
        returns (DelayedAction memory action)
    {
        address usr = address(govActions);
        bytes32 tag;
        assembly {
            tag := extcodehash(usr)
        }
        bytes memory fax =
            abi.encodeWithSignature("setAuthorityAndDelay(address,address,uint256)", pause, newAuthority, newDelay);
        uint256 delay = pause.delay();
        uint256 eta = now + delay;

        pause.plot(usr, tag, fax, eta);
        if (delay == 0) pause.exec(usr, tag, fax, eta);

        return DelayedAction(usr, tag, eta, fax);
    }
}
