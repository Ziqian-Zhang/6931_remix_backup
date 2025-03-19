
// File: @openzeppelin/contracts/utils/Context.sol


// OpenZeppelin Contracts (last updated v5.0.1) (utils/Context.sol)

pragma solidity ^0.8.26;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}

// File: @openzeppelin/contracts/access/Ownable.sol


// OpenZeppelin Contracts (last updated v5.0.0) (access/Ownable.sol)

pragma solidity ^0.8.26;


/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * The initial owner is set to the address provided by the deployer. This can
 * later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    /**
     * @dev The caller account is not authorized to perform an operation.
     */
    error OwnableUnauthorizedAccount(address account);

    /**
     * @dev The owner is not a valid owner account. (eg. `address(0)`)
     */
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the address provided by the deployer as the initial owner.
     */
    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// File: @chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol


pragma solidity ^0.8.26;

interface AggregatorV3Interface {
  function decimals() external view returns (uint8);

  function description() external view returns (string memory);

  function version() external view returns (uint256);

  function getRoundData(
    uint80 _roundId
  ) external view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);

  function latestRoundData()
    external
    view
    returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

// File: @chainlink/contracts/src/v0.8/AutomationBase.sol


pragma solidity ^0.8.26;

contract AutomationBase {
  error OnlySimulatedBackend();

  /**
   * @notice method that allows it to be simulated via eth_call by checking that
   * the sender is the zero address.
   */
  function preventExecution() internal view {
    if (tx.origin != address(0)) {
      revert OnlySimulatedBackend();
    }
  }

  /**
   * @notice modifier that allows it to be simulated via eth_call by checking
   * that the sender is the zero address.
   */
  modifier cannotExecute() {
    preventExecution();
    _;
  }
}

// File: @chainlink/contracts/src/v0.8/interfaces/AutomationCompatibleInterface.sol


pragma solidity ^0.8.26;

interface AutomationCompatibleInterface {
  /**
   * @notice method that is simulated by the keepers to see if any work actually
   * needs to be performed. This method does does not actually need to be
   * executable, and since it is only ever simulated it can consume lots of gas.
   * @dev To ensure that it is never called, you may want to add the
   * cannotExecute modifier from KeeperBase to your implementation of this
   * method.
   * @param checkData specified in the upkeep registration so it is always the
   * same for a registered upkeep. This can easily be broken down into specific
   * arguments using `abi.decode`, so multiple upkeeps can be registered on the
   * same contract and easily differentiated by the contract.
   * @return upkeepNeeded boolean to indicate whether the keeper should call
   * performUpkeep or not.
   * @return performData bytes that the keeper should call performUpkeep with, if
   * upkeep is needed. If you would like to encode data to decode later, try
   * `abi.encode`.
   */
  function checkUpkeep(bytes calldata checkData) external returns (bool upkeepNeeded, bytes memory performData);

  /**
   * @notice method that is actually executed by the keepers, via the registry.
   * The data returned by the checkUpkeep simulation will be passed into
   * this method to actually be executed.
   * @dev The input to this method should not be trusted, and the caller of the
   * method should not even be restricted to any single registry. Anyone should
   * be able call it, and the input should be validated, there is no guarantee
   * that the data passed in is the performData returned from checkUpkeep. This
   * could happen due to malicious keepers, racing keepers, or simply a state
   * change while the performUpkeep transaction is waiting for confirmation.
   * Always validate the data passed in.
   * @param performData is the data which was passed back from the checkData
   * simulation. If it is encoded, it can easily be decoded into other types by
   * calling `abi.decode`. This data should not be trusted, and should be
   * validated against the contract's current state.
   */
  function performUpkeep(bytes calldata performData) external;
}

// File: @chainlink/contracts/src/v0.8/AutomationCompatible.sol


pragma solidity ^0.8.26;



abstract contract AutomationCompatible is AutomationBase, AutomationCompatibleInterface {}

// File: @openzeppelin/contracts/token/ERC20/IERC20.sol


// OpenZeppelin Contracts (last updated v5.1.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.26;

/**
 * @dev Interface of the ERC-20 standard as defined in the ERC.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

// File: contracts/TreasuryDAOTest.sol


pragma solidity ^0.8.26;





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
