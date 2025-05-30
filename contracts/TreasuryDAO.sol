// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;


import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@chainlink/contracts/src/v0.8/AutomationCompatible.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


interface IAaveLendingPool {
   function deposit(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
   function withdraw(address asset, uint256 amount, address to) external;
}


contract TreasuryDAO is Ownable, AutomationCompatible {
   struct Proposal {
       address payable recipient;
       uint256 amount;
       uint256 votes;
       uint256 endTime;
       bool executed;
       uint256 unlockTime;
       mapping(address => bool) voted;
   }


   mapping(address => bool) public members;
   Proposal[] public proposals;
   IERC20 public governanceToken;
   AggregatorV3Interface internal priceFeed;
   IAaveLendingPool public lendingPool;
   uint256 public minVoteDuration = 1 days;


   event ProposalCreated(uint proposalId, address recipient, uint256 amount);
   event Voted(uint proposalId, address voter, uint256 weight);
   event ProposalExecuted(uint proposalId);
   event FundsReleased(uint proposalId);


   constructor(address tokenAddress, address priceFeedAddress, address lendingPoolAddress, address initialOwner)
       Ownable(initialOwner)
   {
       governanceToken = IERC20(tokenAddress);
       priceFeed = AggregatorV3Interface(priceFeedAddress);
       lendingPool = IAaveLendingPool(lendingPoolAddress);
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
       require(getETHPrice() > 1500, "ETH price too low");


       proposal.executed = true;
       proposal.unlockTime = block.timestamp + 48 hours;


       emit ProposalExecuted(proposalId);
   }


   function releaseFunds(uint proposalId) public {
       Proposal storage proposal = proposals[proposalId];
       require(block.timestamp >= proposal.unlockTime, "Funds locked");
       proposal.recipient.transfer(proposal.amount);


       emit FundsReleased(proposalId);
   }


   function getETHPrice() public view returns (uint256) {
       (, int price, , , ) = priceFeed.latestRoundData();
       return uint256(price) / 1e8; // Convert price to USD
   }


   function checkUpkeep(bytes calldata /* checkData */) external view override returns (bool upkeepNeeded, bytes memory performData) {
       for (uint i = 0; i < proposals.length; i++) {
           if (!proposals[i].executed && proposals[i].votes >= 500 * 10**18 && block.timestamp >= proposals[i].endTime) {
               return (true, abi.encode(i));
           }
       }
       return (false, "");
   }


   function performUpkeep(bytes calldata performData) external override {
       uint proposalId = abi.decode(performData, (uint));
       executeProposal(proposalId);
   }


   function depositToAave(uint256 amount) external onlyOwner {
       lendingPool.deposit(address(this), amount, address(this), 0);
   }


   function withdrawFromAave(uint256 amount) external onlyOwner {
       lendingPool.withdraw(address(this), amount, address(this));
   }


   function deposit() public payable {}


   function getBalance() public view returns (uint256) {
       return address(this).balance;
   }
}
