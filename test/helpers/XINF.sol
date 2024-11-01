pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Test Tokens
// Governance Token (MKR)
contract XINF is ERC20 {
    address public gov;
    constructor(uint256 initialSupply) public ERC20("Infinex Token", "XINF") {
        _mint(msg.sender, initialSupply);
    }

    function setGov(address _gov) external {
        require(msg.sender == gov || gov == address(0), "XINF/not-authorized");
        gov = _gov;
    }
}
