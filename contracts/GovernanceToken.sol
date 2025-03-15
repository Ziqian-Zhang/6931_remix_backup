// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract DAOToken is ERC20, Ownable {
   constructor(address initialOwner)
       ERC20("DAO Governance Token", "DAOG")
       Ownable(initialOwner)
   {
       _mint(initialOwner, 1000000 * 10**18); // Mint 1 million tokens to owner
   }


   function mint(address to, uint256 amount) public onlyOwner {
       _mint(to, amount);
   }
}
