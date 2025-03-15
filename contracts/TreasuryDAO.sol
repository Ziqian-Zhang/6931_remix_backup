// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;


import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract TreasuryDAO is Ownable {
   struct Proposal {
       address payable recipient;
       uint256 amount;
       uint256 votes;
       uint256 endTime;
       bool executed;
       mapping(address => bool) voted;
   }


   mapping(address => bool) public members;
   Proposal[] public proposals;
   IERC20 public governanceToken;
   uint256 public minVoteDuration = 1 days;


   event ProposalCreated(uint proposalId, address recipient, uint256 amount);
   event Voted(uint proposalId, address voter, uint256 weight);
   event ProposalExecuted(uint proposalId);


   constructor(address tokenAddress, address initialOwner) Ownable(initialOwner) {
       governanceToken = IERC20(tokenAddress);
       members[initialOwner] = true;
   }


   modifier onlyMember() {
       require(members[msg.sender], "Not a DAO member");
       _;
   }


   function addMember(address member) public onlyOwner {
       members[member] = true;
   }


   function proposeFunding(address payable recipient, uint256 amount) public onlyMember {
       require(address(this).balance >= amount, "Insufficient treasury balance");
       proposals.push();
       Proposal storage newProposal = proposals[proposals.length - 1];
       newProposal.recipient = recipient;
       newProposal.amount = amount;
       newProposal.votes = 0;
       newProposal.endTime = block.timestamp + minVoteDuration;
       newProposal.executed = false;


       emit ProposalCreated(proposals.length - 1, recipient, amount);
   }


   function vote(uint proposalId) public onlyMember {
       Proposal storage proposal = proposals[proposalId];
       require(!proposal.voted[msg.sender], "Already voted");
       require(block.timestamp < proposal.endTime, "Voting period ended");


       uint256 voterBalance = governanceToken.balanceOf(msg.sender);
       require(voterBalance > 0, "Must hold governance tokens to vote");


       proposal.votes += voterBalance;
       proposal.voted[msg.sender] = true;


       emit Voted(proposalId, msg.sender, voterBalance);
   }


   function executeProposal(uint proposalId) public {
       Proposal storage proposal = proposals[proposalId];
       require(proposal.votes >= 500 * 10**18, "Not enough votes (500 tokens required)");
       require(!proposal.executed, "Already executed");
       require(block.timestamp >= proposal.endTime, "Voting period not ended");


       proposal.executed = true;
       proposal.recipient.transfer(proposal.amount);


       emit ProposalExecuted(proposalId);
   }


   function deposit() public payable {}


   function getBalance() public view returns (uint256) {
       return address(this).balance;
   }
}
