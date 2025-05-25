// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/StakingToken.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract StakingTokenTest is Test {
    StakingToken stakingToken;
    string name = "StakingToken";
    string symbol = "STK";
    address user = vm.addr(1);

    function setUp() public {
        stakingToken = new StakingToken(name, symbol);
    }

    function testMint() public {
        vm.startPrank(user);
        uint amount = 1 ether;
        uint balanceBefore = IERC20(address(stakingToken)).balanceOf(user);
        stakingToken.mint(amount);
        uint balanceAfter = IERC20(address(stakingToken)).balanceOf(user);
        assert(balanceAfter - balanceBefore == amount);
        vm.stopPrank();
    }
}
