pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import {DSPause} from "ds-pause/pause.sol";
import {DSAuth} from "ds-auth/auth.sol";
import {GovActions} from "dss-deploy/govActions.sol";
import {DSAuthority} from "ds-auth/auth.sol";

contract ProxyActions is DSAuth {
    DSPause public pause;
    GovActions public govActions;

    constructor(address _pause, address _govActions) public {
        pause = DSPause(_pause);
        govActions = GovActions(_govActions);
        authority = DSAuthority(address(pause.authority()));
    }

    function rely(address from, address to) external auth {
        address usr = address(govActions);
        bytes32 tag;
        assembly {
            tag := extcodehash(usr)
        }
        bytes memory fax = abi.encodeWithSignature("rely(address,address)", from, to);
        uint eta = now;

        pause.plot(usr, tag, fax, eta);
        pause.exec(usr, tag, fax, eta);
    }

    function deny(address from, address to) external auth {
        address usr = address(govActions);
        bytes32 tag;
        assembly {
            tag := extcodehash(usr)
        }
        bytes memory fax = abi.encodeWithSignature("deny(address,address)", from, to);
        uint eta = now;

        pause.plot(usr, tag, fax, eta);
        pause.exec(usr, tag, fax, eta);
    }

    function file(address who, bytes32 what, uint256 data) external auth {
        address usr = address(govActions);
        bytes32 tag;
        assembly {
            tag := extcodehash(usr)
        }
        bytes memory fax = abi.encodeWithSignature("file(address,bytes32,uint256)", who, what, data);
        uint eta = now;

        pause.plot(usr, tag, fax, eta);
        pause.exec(usr, tag, fax, eta);
    }

    function file(address who, bytes32 ilk, bytes32 what, uint256 data) external auth {
        address usr = address(govActions);
        bytes32 tag;
        assembly {
            tag := extcodehash(usr)
        }
        bytes memory fax = abi.encodeWithSignature("file(address,bytes32,bytes32,uint256)", who, ilk, what, data);
        uint eta = now;

        pause.plot(usr, tag, fax, eta);
        pause.exec(usr, tag, fax, eta);
    }

    function dripAndFile(address who, bytes32 what, uint256 data) external auth {
        address usr = address(govActions);
        bytes32 tag;
        assembly {
            tag := extcodehash(usr)
        }
        bytes memory fax = abi.encodeWithSignature("dripAndFile(address,bytes32,uint256)", who, what, data);
        uint eta = now;

        pause.plot(usr, tag, fax, eta);
        pause.exec(usr, tag, fax, eta);
    }

    function dripAndFile(address who, bytes32 ilk, bytes32 what, uint256 data) external auth {
        address usr = address(govActions);
        bytes32 tag;
        assembly {
            tag := extcodehash(usr)
        }
        bytes memory fax = abi.encodeWithSignature(
            "dripAndFile(address,bytes32,bytes32,uint256)",
            who,
            ilk,
            what,
            data
        );
        uint eta = now;

        pause.plot(usr, tag, fax, eta);
        pause.exec(usr, tag, fax, eta);
    }

    function cage(address end) external auth {
        address usr = address(govActions);
        bytes32 tag;
        assembly {
            tag := extcodehash(usr)
        }
        bytes memory fax = abi.encodeWithSignature("cage(address)", end);
        uint eta = now;

        pause.plot(usr, tag, fax, eta);
        pause.exec(usr, tag, fax, eta);
    }

    function setAuthority2(address newAuthority) external auth {
        address usr = address(govActions);
        bytes32 tag;
        assembly {
            tag := extcodehash(usr)
        }
        bytes memory fax = abi.encodeWithSignature("setAuthority(address,address)", pause, newAuthority);
        uint eta = now;

        pause.plot(usr, tag, fax, eta);
        pause.exec(usr, tag, fax, eta);
    }

    function setDelay(uint newDelay) external auth {
        address usr = address(govActions);
        bytes32 tag;
        assembly {
            tag := extcodehash(usr)
        }
        bytes memory fax = abi.encodeWithSignature("setDelay(address,uint256)", pause, newDelay);
        uint eta = now;

        pause.plot(usr, tag, fax, eta);
        pause.exec(usr, tag, fax, eta);
    }

    function setAuthorityAndDelay(address newAuthority, uint newDelay) external auth {
        address usr = address(govActions);
        bytes32 tag;
        assembly {
            tag := extcodehash(usr)
        }
        bytes memory fax = abi.encodeWithSignature(
            "setAuthorityAndDelay(address,address,uint256)",
            pause,
            newAuthority,
            newDelay
        );
        uint eta = now;

        pause.plot(usr, tag, fax, eta);
        pause.exec(usr, tag, fax, eta);
    }
}
