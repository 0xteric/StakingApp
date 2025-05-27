// SPDX-Licenese-Identifier: MIT

pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../src/StakingToken.sol";
import "../src/Staking.sol";

contract StakingTest is Test {
    Staking staking;
    StakingToken stakingToken;

    address owner = vm.addr(1);
    address user1 = vm.addr(2);
    address user2 = vm.addr(3);

    uint public minStakingAmount = 10;
    uint public lockDuration = 7 days;

    function setUp() public {
        stakingToken = new StakingToken("StakingToken", "STK");
        staking = new Staking(address(stakingToken), owner, 10);
    }

    function testStake() public {
        vm.startPrank(user1);
        stakingToken.mint(minStakingAmount);
        stakingToken.approve(address(staking), minStakingAmount);
        staking.stake(minStakingAmount);

        assertEq(minStakingAmount, staking.userBalance(user1));
        vm.stopPrank();
    }

    function testStakeInsufficientAmount() public {
        vm.startPrank(user1);
        uint amountToStake = minStakingAmount - 1;
        stakingToken.mint(amountToStake);
        stakingToken.approve(address(staking), amountToStake);

        vm.expectRevert("Insufficient amount.");
        staking.stake(amountToStake);
    }

    function testRequestWithdraw() public {
        vm.startPrank(user1);

        stakingToken.mint(minStakingAmount);
        stakingToken.approve(address(staking), minStakingAmount);
        staking.stake(minStakingAmount);

        uint8 amountToWithdraw = 5;

        staking.requestWithdraw(5);
        (uint lockedBalance, uint unlockTimestamp) = staking.userLockedBalance(user1);
        vm.stopPrank();

        assertEq(staking.userBalance(user1), 5);
        assertEq(lockedBalance, amountToWithdraw);
        assertEq(unlockTimestamp, block.timestamp + staking.lockDuration());
    }

    function testRequestWithdrawLowBalance() public {
        vm.startPrank(user1);

        stakingToken.mint(minStakingAmount);
        stakingToken.approve(address(staking), minStakingAmount);
        staking.stake(minStakingAmount);

        vm.expectRevert("Balance too low.");
        staking.requestWithdraw(15);
        vm.stopPrank();
    }

    function testWithdraw() public {
        vm.startPrank(user1);

        stakingToken.mint(minStakingAmount);
        stakingToken.approve(address(staking), minStakingAmount);
        staking.stake(minStakingAmount);

        staking.requestWithdraw(5);

        vm.warp(block.timestamp + lockDuration);

        (uint balance, ) = staking.userLockedBalance(user1);
        staking.withdraw(balance);

        (uint newBalance, ) = staking.userLockedBalance(user1);
        assertEq(newBalance, 0);
    }

    function testWithdrawBeforeTime() public {
        vm.startPrank(user1);

        stakingToken.mint(minStakingAmount);
        stakingToken.approve(address(staking), minStakingAmount);
        staking.stake(minStakingAmount);

        staking.requestWithdraw(5);

        vm.expectRevert("Wait until unlock time.");
        staking.withdraw(5);
        vm.stopPrank();
    }

    function testWithdrawLowBalance() public {
        vm.startPrank(user1);

        stakingToken.mint(minStakingAmount);
        stakingToken.approve(address(staking), minStakingAmount);
        staking.stake(minStakingAmount);

        staking.requestWithdraw(5);

        vm.warp(block.timestamp + lockDuration);

        vm.expectRevert("Not enough balance.");
        staking.withdraw(15);
    }

    function testDistributeRewards() public {
        vm.startPrank(user1);
        stakingToken.mint(minStakingAmount);
        stakingToken.approve(address(staking), minStakingAmount);
        staking.stake(minStakingAmount);
        vm.stopPrank();

        vm.startPrank(owner);
        vm.deal(owner, 5 ether);

        (bool success, ) = address(staking).call{value: 5 ether}("");
        require(success, "Distribution failed");
        vm.stopPrank();

        uint userRewards = staking.earned(user1);

        assertEq(staking.rewardPerToken() / 1e18, 5 ether / 10);
        assertEq((staking.userBalance(user1) * staking.rewardPerToken()) / 1e18, userRewards);
    }

    function testStakeAfterDistribution() public {
        vm.startPrank(user1);
        stakingToken.mint(minStakingAmount);
        stakingToken.approve(address(staking), minStakingAmount);
        staking.stake(minStakingAmount);
        vm.stopPrank();

        vm.startPrank(owner);
        vm.deal(owner, 5 ether);

        (bool success1, ) = address(staking).call{value: 5 ether}("");
        require(success1, "Distribution failed");
        vm.stopPrank();

        vm.startPrank(user2);
        uint amountToStake = 30;
        stakingToken.mint(amountToStake);
        stakingToken.approve(address(staking), amountToStake);
        staking.stake(amountToStake);

        uint userRewards = staking.earned(user2);

        assertEq(staking.rewardPerTokenPaid(user2), staking.rewardPerToken());
        assertEq(userRewards, 0);

        vm.stopPrank();
        vm.startPrank(owner);
        vm.deal(owner, 4 ether);

        (bool success2, ) = address(staking).call{value: 4 ether}("");
        require(success2, "Distribution failed");
        vm.stopPrank();
        uint user1Rewards = staking.earned(user1);
        uint user2Rewards = staking.earned(user2);

        // User1 had 5 ether from first distribution for 10 staked tokens
        // 4 ether / 40 total staked tokens = +0.1 rewardPerToken (User1 has 10 staked tokens while User2 has 30)
        assertEq(user1Rewards, 6 ether);
        assertEq(user2Rewards, 3 ether);
    }

    function testClaimRewards() public {
        vm.startPrank(user1);
        stakingToken.mint(minStakingAmount);
        stakingToken.approve(address(staking), minStakingAmount);
        staking.stake(minStakingAmount);
        vm.stopPrank();

        uint ethAmount = 2 ether;
        vm.prank(owner);
        vm.deal(owner, ethAmount);
        (bool success, ) = address(staking).call{value: ethAmount}("");
        require(success, "Test call failed");

        vm.prank(user1);
        staking.claimRewards();

        assertEq(staking.claimedRewards(user1), 2 ether);
    }

    function testClaimNoRewards() public {
        vm.prank(user1);

        vm.expectRevert("No rewards.");
        staking.claimRewards();
    }

    function testChangeLockDuration() public {
        vm.prank(owner);
        staking.changeLockDuration(0 seconds);
    }

    function testChangeMinStakingAmount() public {
        vm.prank(owner);
        uint newMinStakingAmount = 5;
        staking.changeMinStakingAmount(newMinStakingAmount);

        assertEq(staking.minStakingAmount(), newMinStakingAmount);
    }
}
