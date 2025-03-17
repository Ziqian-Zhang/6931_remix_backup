// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;


import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";


contract DAOGToken is ERC20, Ownable {
   using Math for uint256;


   mapping(address => uint256) public stakedTokens;
   mapping(address => uint256) public stakingStart;


   constructor(address initialOwner)
       ERC20("DAO Governance Token", "DAOG")
       Ownable(initialOwner)
   {
       _mint(initialOwner, 1000000 * 10**18); // Mint 1 million tokens to owner
   }


   function mint(address to, uint256 amount) public onlyOwner {
       _mint(to, amount);
   }


   // Quadratic Voting Calculation
   function getVotingPower(address user) public view returns (uint256) {
       return Math.sqrt(stakedTokens[user]);
   }


   // Staking function
   function stakeTokens(uint256 amount) external {
       require(balanceOf(msg.sender) >= amount, "Insufficient balance");
       _transfer(msg.sender, address(this), amount);
       stakedTokens[msg.sender] += amount;
       stakingStart[msg.sender] = block.timestamp;
   }


   // Unstaking with vesting bonus
   function unstakeTokens() external {
       require(stakedTokens[msg.sender] > 0, "No staked tokens");


       uint256 stakingDuration = block.timestamp - stakingStart[msg.sender];
       uint256 bonus = calculateVestingBonus(stakedTokens[msg.sender], stakingDuration);


       uint256 totalAmount = stakedTokens[msg.sender] + bonus;
       stakedTokens[msg.sender] = 0;
       _transfer(address(this), msg.sender, totalAmount);
   }


   // Vesting calculation for staking rewards
   function calculateVestingBonus(uint256 amount, uint256 duration) internal pure returns (uint256) {
       uint256 months = duration / 30 days;
       return (amount * months) / 100; // 1% bonus per month
   }
}