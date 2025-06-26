// SPDX-Licenese-Identifier: MIT

pragma solidity ^0.8.24;

import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract Staking is Ownable {
    struct LockedBalance {
        uint balance;
        uint unlockTimestamp;
    }

    address public stakingToken;
    address public admin;

    uint public minStakingAmount;
    uint public rewardPerToken;
    uint public totalStaked;
    uint public lockDuration;

    mapping(address => uint) public userBalance;
    mapping(address => LockedBalance) public userLockedBalance;
    mapping(address => uint) public claimedRewards;
    mapping(address => uint) public rewards;
    mapping(address => uint) public rewardPerTokenPaid;

    event ChangeStakingPeriod(uint newStakingPeriod);
    event Staked(address user, uint amount);
    event RequestWithdraw(address user, uint amount);
    event Withdrawn(address user, uint amount);
    event EthReceived(uint amount);
    event RewardsClaimed(address user, uint amount);

    constructor(address _stakingToken, address _owner, uint _minStakingAmount) Ownable(_owner) {
        stakingToken = _stakingToken;
        minStakingAmount = _minStakingAmount;
        lockDuration = 7 days;
    }

    /**
     * Updates the user rewards and rewardPerToken snapshot of a user
     * @param _user user address
     */
    modifier updateRewards(address _user) {
        rewards[_user] = earned(_user);
        rewardPerTokenPaid[_user] = rewardPerToken;
        _;
    }

    /**
     * Returns the amount of rewards claimable of a user
     * @param _user user address
     */
    function earned(address _user) public view returns (uint) {
        return (userBalance[_user] * (rewardPerToken - rewardPerTokenPaid[_user])) / 1e18 + rewards[_user];
    }

    /**
     * Stakes the amount of tokens selected
     * @param _amount amount to stake
     */
    function stake(uint _amount) external updateRewards(msg.sender) {
        require(_amount >= minStakingAmount, "Insufficient amount.");

        totalStaked += _amount;

        IERC20(stakingToken).transferFrom(msg.sender, address(this), _amount);

        userBalance[msg.sender] += _amount;

        emit Staked(msg.sender, _amount);
    }

    /**
     * Starts an staking unlock period for the amount of staked tokens selected
     * @param _amount amount of tokens to unstake
     */
    function requestWithdraw(uint _amount) public updateRewards(msg.sender) {
        require(_amount <= userBalance[msg.sender], "Balance too low.");
        userBalance[msg.sender] -= _amount;
        userLockedBalance[msg.sender].balance += _amount;
        userLockedBalance[msg.sender].unlockTimestamp = block.timestamp + lockDuration;
        emit RequestWithdraw(msg.sender, _amount);
    }

    /**
     * Withdraws the amount of tokens selected from the unlocked requested tokens
     * @param _amount amount to withdraw
     */
    function withdraw(uint _amount) external {
        require(block.timestamp >= userLockedBalance[msg.sender].unlockTimestamp, "Wait until unlock time.");
        require(userLockedBalance[msg.sender].balance >= _amount, "Not enough balance.");
        userLockedBalance[msg.sender].balance -= _amount;
        IERC20(stakingToken).transfer(msg.sender, _amount);
        emit Withdrawn(msg.sender, _amount);
    }

    /**
     * Claims the rewards accumulated
     */
    function claimRewards() external updateRewards(msg.sender) {
        uint userRewards = rewards[msg.sender];
        require(userRewards > 0, "No rewards.");
        rewards[msg.sender] = 0;
        claimedRewards[msg.sender] += userRewards;
        (bool success, ) = msg.sender.call{value: userRewards}("");
        require(success, "Transfer failed");
        emit RewardsClaimed(msg.sender, userRewards);
    }

    /**
     * Receives the rewards
     */
    receive() external payable onlyOwner {
        rewardPerToken += (msg.value * 1e18) / totalStaked;
        emit EthReceived(msg.value);
    }

    /**
     * Updates Unlock period duration
     * @param _newDuration new duration
     */
    function changeLockDuration(uint _newDuration) external onlyOwner {
        lockDuration = _newDuration;
    }

    /**
     * Updates the minimum amount of tokens needed to stake
     * @param newMinStakingAmount new amount
     */
    function changeMinStakingAmount(uint newMinStakingAmount) external onlyOwner {
        minStakingAmount = newMinStakingAmount;
    }
}
