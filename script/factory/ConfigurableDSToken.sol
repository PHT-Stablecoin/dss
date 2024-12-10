pragma solidity ^0.6.12;

import {DSMath} from "ds-math/math.sol";
import {DSAuth} from "ds-auth/auth.sol";

// Copy of DSToken with maxSupply check
contract ConfigurableDSToken is DSMath, DSAuth {
    bool public stopped;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    string public symbol;
    uint8 public decimals;
    string public name = "";
    uint256 public maxSupply;

    event Approval(address indexed src, address indexed guy, uint wad);
    event Transfer(address indexed src, address indexed dst, uint wad);
    event Mint(address indexed guy, uint wad);
    event Burn(address indexed guy, uint wad);
    event Stop();
    event Start();

    modifier stoppable() {
        require(!stopped, "ds-stop-is-stopped");
        _;
    }

    constructor(string memory symbol_, string memory name_, uint8 decimals_, uint256 maxSupply_) public {
        symbol = symbol_;
        name = name_;
        decimals = decimals_;
        maxSupply = maxSupply_;
    }

    function approve(address guy) external returns (bool) {
        return approve(guy, uint(-1));
    }

    function approve(address guy, uint wad) public stoppable returns (bool) {
        allowance[msg.sender][guy] = wad;
        emit Approval(msg.sender, guy, wad);
        return true;
    }

    function transfer(address dst, uint wad) external returns (bool) {
        return transferFrom(msg.sender, dst, wad);
    }

    function transferFrom(address src, address dst, uint wad) public stoppable returns (bool) {
        if (src != msg.sender && allowance[src][msg.sender] != uint(-1)) {
            require(allowance[src][msg.sender] >= wad, "ds-token-insufficient-approval");
            allowance[src][msg.sender] = sub(allowance[src][msg.sender], wad);
        }

        require(balanceOf[src] >= wad, "ds-token-insufficient-balance");
        balanceOf[src] = sub(balanceOf[src], wad);
        balanceOf[dst] = add(balanceOf[dst], wad);

        emit Transfer(src, dst, wad);
        return true;
    }

    function push(address dst, uint wad) external {
        transferFrom(msg.sender, dst, wad);
    }

    function pull(address src, uint wad) external {
        transferFrom(src, msg.sender, wad);
    }

    function move(address src, address dst, uint wad) external {
        transferFrom(src, dst, wad);
    }

    function burn(uint wad) external {
        burn(msg.sender, wad);
    }

    // Modified mint functions with maxSupply check
    function mint(uint wad) external {
        if (maxSupply > 0) {
            require(add(totalSupply, wad) <= maxSupply, "ds-token-exceeds-maximum-supply");
        }
        mint(msg.sender, wad);
    }

    function mint(address guy, uint wad) public auth stoppable {
        if (maxSupply > 0) {
            require(add(totalSupply, wad) <= maxSupply, "ds-token-exceeds-maximum-supply");
        }
        balanceOf[guy] = add(balanceOf[guy], wad);
        totalSupply = add(totalSupply, wad);
        emit Mint(guy, wad);
    }

    function burn(address guy, uint wad) public auth stoppable {
        if (guy != msg.sender && allowance[guy][msg.sender] != uint(-1)) {
            require(allowance[guy][msg.sender] >= wad, "ds-token-insufficient-approval");
            allowance[guy][msg.sender] = sub(allowance[guy][msg.sender], wad);
        }

        require(balanceOf[guy] >= wad, "ds-token-insufficient-balance");
        balanceOf[guy] = sub(balanceOf[guy], wad);
        totalSupply = sub(totalSupply, wad);
        emit Burn(guy, wad);
    }

    function stop() public auth {
        stopped = true;
        emit Stop();
    }

    function start() public auth {
        stopped = false;
        emit Start();
    }

    function setName(string memory name_) public auth {
        name = name_;
    }
}
