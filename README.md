# Staking Smart Contract

This repository contains a simple and secure Ethereum staking contract that allows users to stake an ERC20 token, earn ETH rewards, and withdraw their stake after a lock period.

## 📜 Contract Overview

The `Staking` smart contract enables users to:

- Stake ERC20 tokens
- Accumulate ETH rewards distributed proportionally based on stake
- Request withdrawal of their stake, subject to a time lock
- Claim earned ETH rewards at any time
- Allows the contract owner to adjust parameters like minimum stake and lock duration

## ⚙️ How It Works

1. **Staking**  
   Users stake a specified ERC20 token by calling `stake(uint amount)` after approving the contract to transfer tokens.

2. **Withdraw Request**  
   Users initiate a withdrawal request using `requestWithdraw(uint amount)`, which sets a 7-day (by default) lock before tokens can be withdrawn.

3. **Withdraw**  
   After the lock period, users can call `withdraw(uint amount)` to retrieve their tokens.

4. **Reward Distribution**  
   ETH sent to the contract (via `receive()`) by the owner is distributed among stakers. Rewards can be claimed using `claimRewards()`.
