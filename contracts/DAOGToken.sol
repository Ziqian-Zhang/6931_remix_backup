// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DAOGToken is ERC20, Ownable {
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

    function stake(uint256 amount) public {
        require(balanceOf(msg.sender) >= amount, "Not enough tokens to stake");
        _transfer(msg.sender, address(this), amount);

        if (stakedTokens[msg.sender] == 0) {
            stakingStart[msg.sender] = block.timestamp; // Track staking time
        }

        stakedTokens[msg.sender] += amount;
    }

    function getVotingPower(address user) public view returns (uint256) {
        uint256 timeStaked = block.timestamp - stakingStart[user];
        uint256 weight = 1 + (timeStaked / 30 days); // 1x multiplier every 30 days
        return sqrt(stakedTokens[user]) * weight;
    }

    function sqrt(uint256 x) internal pure returns (uint256) {
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }
}
