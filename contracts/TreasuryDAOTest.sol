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
       address payable recipient; // Address of the proposal recipient
       uint256 amount; // Amount of funds requested
       uint256 votes; // Total votes received
       uint256 endTime; // Proposal expiration time (after voting period)
       bool executed; // Whether the proposal has been executed
       uint256 unlockTime; // Time when funds can be withdrawn
       mapping(address => bool) voted; // Tracks whether a member has voted
   }

   mapping(address => bool) public members; // Tracks DAO members
   Proposal[] public proposals; // Array of proposals
   IERC20 public governanceToken; // Governance token used for voting
   AggregatorV3Interface internal priceFeed; // Chainlink Price Oracle for ETH/USD
   IAaveLendingPool public lendingPool; // Aave Lending Pool for yield farming
   uint256 public minVoteDuration = 1 minutes; // Voting period set to 1 minute for fast testing

   event ProposalCreated(uint proposalId, address recipient, uint256 amount);
   event Voted(uint proposalId, address voter, uint256 weight);
   event ProposalExecuted(uint proposalId);
   event FundsReleased(uint proposalId);

   // Constructor: Initializes the DAO with token, oracle, and Aave lending pool addresses.
   constructor(address tokenAddress, address priceFeedAddress, address lendingPoolAddress, address initialOwner)
       Ownable(initialOwner)
   {
       governanceToken = IERC20(tokenAddress);
       priceFeed = AggregatorV3Interface(priceFeedAddress);
       lendingPool = IAaveLendingPool(lendingPoolAddress);
       members[initialOwner] = true; // Set the contract deployer as the first DAO member
   }

   // Modifier: Ensures only DAO members can call a function.
   modifier onlyMember() {
       require(members[msg.sender], "Not a DAO member");
       _;
   }

   // Adds a new member to the DAO.
   function addMember(address member) public onlyOwner {
       members[member] = true;
   }

   // Allows a DAO member to propose funding.
   function proposeFunding(address payable recipient, uint256 amount) public onlyMember {
       require(address(this).balance >= amount, "Insufficient treasury balance");
       
       proposals.push();
       Proposal storage newProposal = proposals[proposals.length - 1];
       newProposal.recipient = recipient;
       newProposal.amount = amount;
       newProposal.votes = 0;
       newProposal.endTime = block.timestamp + minVoteDuration; // **Set voting period to 1 minute**
       newProposal.executed = false;

       emit ProposalCreated(proposals.length - 1, recipient, amount);
   }

   // Allows a DAO member to vote on a proposal.
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

   // Executes a proposal after the voting period has ended and if it has enough votes.
   function executeProposal(uint proposalId) public {
       Proposal storage proposal = proposals[proposalId];
       require(proposal.votes >= 500 * 10**18, "Not enough votes (500 tokens required)");
       require(!proposal.executed, "Already executed");
       require(block.timestamp >= proposal.endTime, "Voting period not ended");
       require(getETHPrice() > 1500, "ETH price too low"); // Ensures ETH price is safe for funding

       proposal.executed = true;
       proposal.unlockTime = block.timestamp + 1 minutes; // **Funds unlock in 1 minute**

       emit ProposalExecuted(proposalId);
   }

   // Allows the recipient to withdraw funds after the unlock period.
   function releaseFunds(uint proposalId) public {
       Proposal storage proposal = proposals[proposalId];
       require(block.timestamp >= proposal.unlockTime, "Funds locked for 1 minute");
       proposal.recipient.transfer(proposal.amount);

       emit FundsReleased(proposalId);
   }

   // Fetches the latest ETH/USD price from Chainlink Oracle.
   function getETHPrice() public view returns (uint256) {
       (, int price, , , ) = priceFeed.latestRoundData();
       return uint256(price) / 1e8; // Convert price to USD with decimals removed
   }

   // Chainlink Automation: Checks if any proposal is eligible for execution.
   function checkUpkeep(bytes calldata /* checkData */) external view override returns (bool upkeepNeeded, bytes memory performData) {
       for (uint i = 0; i < proposals.length; i++) {
           if (!proposals[i].executed && proposals[i].votes >= 500 * 10**18 && block.timestamp >= proposals[i].endTime) {
               return (true, abi.encode(i));
           }
       }
       return (false, "");
   }

   // Chainlink Automation: Performs automatic execution of eligible proposals.
   function performUpkeep(bytes calldata performData) external override {
       uint proposalId = abi.decode(performData, (uint));
       executeProposal(proposalId);
   }

   // Deposits ETH into Aave lending pool to earn yield.
   function depositToAave(uint256 amount) external onlyOwner {
       lendingPool.deposit(address(this), amount, address(this), 0);
   }

   // Withdraws ETH from Aave lending pool back to the DAO.
   function withdrawFromAave(uint256 amount) external onlyOwner {
       lendingPool.withdraw(address(this), amount, address(this));
   }

   // Allows anyone to deposit ETH into the DAO Treasury.
   function deposit() public payable {}

   // Returns the current balance of ETH in the DAO Treasury.
   function getBalance() public view returns (uint256) {
       return address(this).balance;
   }
}
