pragma solidity 0.4.24;

/*
Backerr.io (C) 2019
Description: Uses Chainlink to allow creators to charge subscriptions for their content.
Creators can start Projects and subscribers can donate money to them. The Chainlink smart contract is hooked up
to fetch ETH/USD exchange rate from Crypotcompare.com.
*/

import "https://github.com/smartcontractkit/chainlink/blob/develop/evm/contracts/ChainlinkClient.sol";
import "https://github.com/smartcontractkit/chainlink/blob/develop/evm/contracts/vendor/Ownable.sol";
import "https://github.com/smartcontractkit/chainlink/blob/develop/evm/contracts/vendor/SafeMath.sol";

contract BackerrV1 is ChainlinkClient, Ownable {
  uint256 constant private ORACLE_PAYMENT = 1 * LINK; // solium-disable-line zeppelin/no-arithmetic-operations

  mapping(bytes32 => uint256) internal prices;
  mapping(bytes32 => bytes32) internal receipts;

  // List of existing projects
  Project[] private projects;
  // Mapping of vanity URLs to existing projects
  mapping(string => Project) projectsByURL;

  // Event that will be emitted whenever a new project is started
  event ProjectStarted(
        address contractAddress,
        address projectStarter,
        string projectTitle,
        string projectDesc,
        string projectUrl,
        uint256 deadline,
        uint256 goalAmount
   );

  // link: 0x0000000000000000000000000000000000000000
  constructor(address _link) public {
    // Set the address for the LINK token for the network.
    if(_link == address(0)) {
      // Useful for deploying to public networks.
      setPublicChainlinkToken();
    } else {
      // Useful if you're deploying to a local network.
      setChainlinkToken(_link);
    }
  }

  // oracle: "0xc99B3D447826532722E41bc36e644ba3479E4365"
  // jobId: "3cff0a3524694ff8834bda9cf9c779a1"
  // uniqueId: 0x7465737400000000000000000000000000000000000000000000000000000000
  function requestEthereumPrice(address _oracle, string _jobId, bytes32 _uniqueId)
    public
    onlyOwner
  {
    Chainlink.Request memory req = buildChainlinkRequest(stringToBytes32(_jobId), this, this.fulfillEthereumPrice.selector);
    req.add("url", "https://min-api.cryptocompare.com/data/price?fsym=ETH&tsyms=USD");
    req.add("path", "USD");
    req.addInt("times", 100);
    receipts[sendChainlinkRequestTo(_oracle, req, ORACLE_PAYMENT)] = _uniqueId;
  }

  function fulfillEthereumPrice(bytes32 _requestId, uint256 _price)
    public
    recordChainlinkFulfillment(_requestId)
  {
    bytes32 uniqueId = receipts[_requestId];
    delete receipts[_requestId];
    prices[uniqueId] = _price;
  }

  function getPrice(bytes32 _uniqueId) public view returns (uint256) {
    return prices[_uniqueId];
  }

  function getChainlinkToken() public view returns (address) {
    return chainlinkTokenAddress();
  }

  function withdrawLink() public onlyOwner {
    LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
    require(link.transfer(msg.sender, link.balanceOf(address(this))), "Unable to transfer");
  }

  function stringToBytes32(string memory source) private pure returns (bytes32 result) {
    bytes memory tempEmptyStringTest = bytes(source);
    if (tempEmptyStringTest.length == 0) {
      return 0x0;
    }

    assembly {
      result := mload(add(source, 32))
    }
  }

      /** @dev Function to get a specific project
      * @return A single project struct
    */
    function getProject(string memory urlString) public view returns  (address projectStarter,
        string memory projectTitle,
        string memory projectDesc,
        address projectContract,
        uint256 created,
        uint256 deadline,
        uint256 currentAmount,
        uint256 goalAmount,
        uint256 state) {
        return projectsByURL[urlString].getDetailsWithoutState();
    }

    /** @dev Function to get a specific project
      * @return A single project struct
    */
    function getProjectCreator(string memory urlString) public view returns (address) {
        return address(projectsByURL[urlString].creator);
    }

    /** @dev Function to start a new project.
      * @param title Title of the project to be created
      * @param description Brief description about the project
      * @param durationInDays Project deadline in days
      * @param amountToRaise Project goal in wei
      */
    function startProject(
        string title,
        string description,
        string urlString,
        uint durationInDays,
        uint amountToRaise
    ) external {
        require(getProjectCreator(urlString) == address(0), "Duplicate key"); // duplicate key
        uint raiseUntil = now.add(durationInDays.mul(1 days));
        Project newProject = new Project(msg.sender, title, description, urlString, raiseUntil, amountToRaise);
        projects.push(newProject);
        projectsByURL[urlString] = newProject;
        emit ProjectStarted(
            address(newProject),
            msg.sender,
            title,
            description,
            urlString,
            raiseUntil,
            amountToRaise
        );
    }

    /** @dev Function to get all projects' contract addresses.
      * @return A list of all projects' contract addreses
      */
    function returnAllProjects() external view returns(Project[] memory){
        return projects;
    }

}

contract Project {
    using SafeMath for uint256;

    // Data structures
    enum State {
        Fundraising,
        Expired,
        Successful
    }

    // State variables
    address public creator;
    uint public amountGoal; // required to reach at least this much, else everyone gets refund
    uint public completeAt;
    uint256 public currentBalance;
    uint public raiseBy;
    string public title;
    string public description;
    string public urlString;
    State public state = State.Fundraising; // initialize on create
    mapping (address => uint) public contributions;

    // Event that will be emitted whenever funding will be received
    event FundingReceived(address contributor, uint amount, uint currentTotal);
    // Event that will be emitted whenever the project starter has received the funds
    event CreatorPaid(address recipient);

    // Modifier to check current state
    modifier inState(State _state) {
        require(state == _state);
        _;
    }

    // Modifier to check if the function caller is the project creator
    modifier isCreator() {
        require(msg.sender == creator);
        _;
    }

    constructor
    (
        address projectStarter,
        string memory projectTitle,
        string memory projectDesc,
        string memory projectUrl,
        uint fundRaisingDeadline,
        uint goalAmount
    ) public {
        creator = projectStarter;
        title = projectTitle;
        description = projectDesc;
        urlString = projectUrl;
        amountGoal = goalAmount;
        raiseBy = fundRaisingDeadline;
        currentBalance = 0;
    }

    /** @dev Function to fund a certain project.
      */
    function contribute() external inState(State.Fundraising) payable {
        require(msg.sender != creator);
        contributions[msg.sender] = contributions[msg.sender].add(msg.value);
        currentBalance = currentBalance.add(msg.value);
        emit FundingReceived(msg.sender, msg.value, currentBalance);
        checkIfFundingCompleteOrExpired();
    }

    /** @dev Function to change the project state depending on conditions.
      */
    function checkIfFundingCompleteOrExpired() public {
        if (currentBalance >= amountGoal) {
            state = State.Successful;
            payOut();
        } else if (now > raiseBy)  {
            state = State.Expired;
        }
        completeAt = now;
    }

    /** @dev Function to give the received funds to project starter.
      */
    function payOut() internal inState(State.Successful) returns (bool) {
        uint256 totalRaised = currentBalance;
        currentBalance = 0;

        if (creator.send(totalRaised)) {
            emit CreatorPaid(creator);
            return true;
        } else {
            currentBalance = totalRaised;
            state = State.Successful;
        }

        return false;
    }

    /** @dev Function to retrieve donated amount when a project expires.
      */
    function getRefund() public inState(State.Expired) returns (bool) {
        require(contributions[msg.sender] > 0);

        uint amountToRefund = contributions[msg.sender];
        contributions[msg.sender] = 0;

        if (!msg.sender.send(amountToRefund)) {
            contributions[msg.sender] = amountToRefund;
            return false;
        } else {
            currentBalance = currentBalance.sub(amountToRefund);
        }

        return true;
    }

     /** @dev Function to get specific information about the project.
      * @return Returns all the project's details
      */
    function getDetailsWithoutState() public view returns
    (
        address projectStarter,
        string memory projectTitle,
        string memory projectDesc,
        address projectContract,
        uint256 created,
        uint256 deadline,
        uint256 currentAmount,
        uint256 goalAmount,
        uint256 stated
    ) {
        projectStarter = creator;
        projectTitle = title;
        projectDesc = description;
        projectContract = address(this);
        created = now;
        deadline = raiseBy;
        currentAmount = currentBalance;
        goalAmount = amountGoal;
        stated = uint(state);
    }
}
