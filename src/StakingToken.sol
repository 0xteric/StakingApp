// SPDX-Licenese-Identifier: MIT

pragma solidity ^0.8.24;

import "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract StakingToken is ERC20 {
    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {}

    function mint(uint _amount) external {
        _mint(msg.sender, _amount);
    }
}
