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

    function setUp() public {
        stakingToken = new StakingToken("StakingToken", "STK");
        staking = new Staking(address(stakingToken), owner, 10);
    }

    function testStake() public {
        uint8 amountToStake = 10;

        vm.startPrank(user1);
        stakingToken.mint(amountToStake);
        stakingToken.approve(address(staking), amountToStake);
        staking.stake(amountToStake);

        assertEq(amountToStake, staking.userBalance(user1));
        vm.stopPrank();
    }

    function testStakeInsufficientAmount() public {
        vm.startPrank(user1);
        uint8 amountToStake = 5;
        stakingToken.mint(amountToStake);
        stakingToken.approve(address(staking), amountToStake);

        vm.expectRevert("Insufficient amount.");
        staking.stake(amountToStake);
    }

    function testRequestWithdraw() public {
        testStake();
        uint8 amountToWithdraw = 5;

        vm.prank(user1);

        staking.requestWithdraw(5);
        (uint lockedBalance, uint unlockTimestamp) = staking.userLockedBalance(user1);

        assertEq(staking.userBalance(user1), 5);
        assertEq(lockedBalance, amountToWithdraw);
        assertEq(unlockTimestamp, block.timestamp + staking.lockDuration());
    }

    function testRequestWithdrawLowBalance() public {
        testStake();

        vm.prank(user1);

        vm.expectRevert("Balance too low.");
        staking.requestWithdraw(15);
    }

    function testWithdraw() public {
        uint8 amountToStake = 10;
        testChangeLockDuration();

        vm.startPrank(user1);

        stakingToken.mint(amountToStake);
        stakingToken.approve(address(staking), amountToStake);
        staking.stake(amountToStake);

        staking.requestWithdraw(5);

        (uint balance, ) = staking.userLockedBalance(user1);
        staking.withdraw(balance);

        (uint newBalance, ) = staking.userLockedBalance(user1);
        assertEq(newBalance, 0);
    }

    function testWithdrawBeforeTime() public {
        testRequestWithdraw();
        vm.prank(user1);

        vm.expectRevert("Wait until unlock time.");
        staking.withdraw(5);
    }

    function testWithdrawLowBalance() public {
        testChangeLockDuration();
        testRequestWithdraw();
        vm.prank(user1);

        vm.expectRevert("Not enough balance.");
        staking.withdraw(15);
    }

    function testDistributeRewards() public {
        testStake();
        vm.startPrank(owner);
        vm.deal(owner, 5 ether);
        (bool success, ) = address(staking).call{value: 5 ether}("");
        require(success, "Distribution failed");
        uint userRewards = staking.earned(user1);

        assertEq(staking.rewardPerToken() / 1e18, 5 ether / 10);
        assertEq((staking.userBalance(user1) * staking.rewardPerToken()) / 1e18, userRewards);
    }

    function testStakeAfterDistribution() public {
        testDistributeRewards();
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

        (bool success, ) = address(staking).call{value: 4 ether}("");
        require(success, "Distribution failed");
        vm.stopPrank();
        uint user1Rewards = staking.earned(user1);
        uint user2Rewards = staking.earned(user2);

        // User1 had 5 ether from first distribution for 10 staked tokens
        // 4 ether / 40 total staked tokens = +0.1 rewardPerToken (User1 has 10 staked tokens while User2 has 30)
        assertEq(user1Rewards, 6 ether);
        assertEq(user2Rewards, 3 ether);
    }

    function testClaimRewards() public {
        testStakeAfterDistribution();

        vm.prank(user1);
        staking.claimRewards();

        vm.prank(user2);
        staking.claimRewards();

        assertEq(staking.claimedRewards(user1), 6 ether);
        assertEq(staking.claimedRewards(user2), 3 ether);
        assertEq(staking.rewards(user1), staking.rewards(user2));
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
