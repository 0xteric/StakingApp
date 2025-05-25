// SPDX-Licenese-Identifier: MIT

pragma solidity ^0.8.24;

import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract Staking is Ownable {
    address public stakingToken;
    address public admin;
    uint public stakingPeriod;
    uint public minStakingAmount;
    uint public rewardPerToken;

    mapping(address => uint) public userBalance;
    mapping(address => uint) public depositTime;
    mapping(address => uint) public claimedRewards;

    event ChangeStakingPeriod(uint newStakingPeriod);
    event Deposit(address user, uint amount);
    event Withdraw(address user, uint amount);
    event EthReceived(uint amount);

    constructor(address _stakingToken, address _owner, uint _stakingPeriod, uint _minStakingAmount) Ownable(_owner) {
        stakingToken = _stakingToken;
        stakingPeriod = _stakingPeriod;
        minStakingAmount = _minStakingAmount;
    }

    function deposit(uint _amount) external {
        require(_amount >= minStakingAmount, "Not enough amount.");
        IERC20(stakingToken).transferFrom(msg.sender, address(this), _amount);

        userBalance[msg.sender] += _amount;
        depositTime[msg.sender] = block.timestamp;

        emit Deposit(msg.sender, _amount);
    }

    function withdraw(uint _amount) external {
        require(userBalance[msg.sender] >= _amount, "Not enough balance.");
        userBalance[msg.sender] -= _amount;
        IERC20(stakingToken).transfer(msg.sender, _amount);
    }

    function claimRewards() external {
        require(userBalance[msg.sender] >= minStakingAmount, "Not staking.");
        uint elapsePeriod = block.timestamp - depositTime[msg.sender];
        require(elapsePeriod >= stakingPeriod, "Wait to staking period");
        depositTime[msg.sender] = block.timestamp;
        (bool success, ) = msg.sender.call{value: rewardPerToken}("");
        require(success, "Transfer failed");
    }

    function getUserRewards(address _user) public view returns (uint) {
        uint balance = userBalance[_user];
        uint rewards = balance * rewardPerToken;
        return rewards - claimedRewards[_user];
    }

    receive() external payable onlyOwner {
        emit EthReceived(msg.value);
    }

    function changeStakingPeriod(uint newStakingPeriod) external onlyOwner {
        stakingPeriod = newStakingPeriod;
    }

    function changeMinStakingAmount(uint newMinStakingAmount) external onlyOwner {
        minStakingAmount = newMinStakingAmount;
    }
}
