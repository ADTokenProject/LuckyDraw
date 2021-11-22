// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;


import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./IRandomNumberGenerator.sol";


//Have fun reading it. Hopefully it's bug-free. God bless.
contract LuckyDraw is Ownable {

    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Represents the status of the draw
    enum Status {
        Open, //Anyone can enter the draw
        Closed, //Unable to participate in the draw, waiting for the draw or drawing
        Completed       // The drawing has been completed
    }

    // All the needed info around a LuckyDraw
    struct LuckyDrawInfo {
        Status status;       // Status for LuckyDrawInfo
        uint256 stakeAmount; //The AMOUNT of AD pledged to participate in the activity
        uint256 prizeAmount;//Prize (BUSD)
        uint256 minPlayerSize;//Minimum participants
        uint256 startTime;
        uint256 endTime;
        address winner;
        address[] player;
    }

    // all LuckyDrawInfo
    mapping(uint256 => LuckyDrawInfo) public allLuckyDraw;
    //Redemption information: Record whether a prize has been redeemed
    mapping(uint256 => mapping(address => bool)) public claimRewardInfo;

    // Counter for LuckyDrawInfo IDs
    uint256 public luckyDrawIdCounter;

    //Random number generation
    IRandomNumberGenerator internal randomGenerator;
    //Request ID of random number
    bytes32 internal requestId;

    IERC20 stakeToken;
    IERC20 prizeToken;

    modifier onlyRandomGenerator() {
        require(
            msg.sender == address(randomGenerator),
            "Only random generator"
        );
        _;
    }


    //event
    event LuckyDrawOpen(uint256 luckyDrawId);
    event LuckyDrawClose(uint256 luckyDrawId);
    event Stake(address indexed user, uint256 indexed luckyDrawId);
    event RequestNumbers(uint256 luckyDrawId, bytes32 requestId);

    constructor(IERC20 _stakeToken, IERC20 _prizeToken) public {
        stakeToken = _stakeToken;
        prizeToken = _prizeToken;
    }

    function initRandomNumberGenerator(address _randomGenerator) external onlyOwner() {
        require(_randomGenerator != address(0), "Contracts cannot be 0 address");
        randomGenerator = IRandomNumberGenerator(_randomGenerator);
    }

    //Create a new LuckyDraw: Be sure to approve this function before calling it
    function createNewLuckyDraw(uint256 _stakeAmount, uint256 _prizeAmount, uint256 _minPlayerSize, uint256 _awaitTime) public onlyOwner returns (uint256 luckyDrawId){
        require(_prizeAmount > 0 && _stakeAmount > 0 && _minPlayerSize > 0 && _awaitTime > 0, "Error: Parameter Error Please Check");
        prizeToken.safeTransferFrom(address(msg.sender), address(this), _prizeAmount);
        // Saving data in struct
        luckyDrawIdCounter = luckyDrawIdCounter.add(1);
        luckyDrawId = luckyDrawIdCounter;
        LuckyDrawInfo storage newLuckyDraw = allLuckyDraw[luckyDrawId];
        newLuckyDraw.status = Status.Open;
        newLuckyDraw.minPlayerSize = _minPlayerSize;
        newLuckyDraw.stakeAmount = _stakeAmount;
        newLuckyDraw.prizeAmount = _prizeAmount;
        newLuckyDraw.startTime = block.timestamp;
        newLuckyDraw.endTime = block.timestamp + _awaitTime;
        emit LuckyDrawOpen(luckyDrawId);
    }

    //Pledge to participate in the draw: Please approve sufficient pledge token amount prior to this
    function stake(uint256 _luckyDrawId) public {
        LuckyDrawInfo storage luckyDrawInfo = allLuckyDraw[_luckyDrawId];
        require(block.timestamp < luckyDrawInfo.endTime, "Error: Lucky draw has ended");
        require(luckyDrawInfo.status == Status.Open, "Error: LuckyDraw not open");
        require(!checkStake(msg.sender, _luckyDrawId), "Error: already entered the LuckyDraw");
        stakeToken.safeTransferFrom(address(msg.sender), address(this), luckyDrawInfo.stakeAmount);
        luckyDrawInfo.player.push(msg.sender);
        emit Stake(msg.sender, _luckyDrawId);
    }


    //Redemption: the return of principal and rewards (if winning)
    function claimReward(uint256 _luckyDrawId) public {
        LuckyDrawInfo storage luckyDrawInfo = allLuckyDraw[_luckyDrawId];
        require(block.timestamp >= luckyDrawInfo.endTime, "Error: The LuckyDraw is not over yet");
        require(luckyDrawInfo.status == Status.Completed, "Error: Drawing not completed");
        require(checkStake(msg.sender, _luckyDrawId), "Error: you did not enter the LuckyDraw");
        require(!claimRewardInfo[_luckyDrawId][msg.sender], "Error: Prize already paid");
        stakeToken.safeTransfer(address(msg.sender), luckyDrawInfo.stakeAmount);

        if (luckyDrawInfo.winner == msg.sender) {
            prizeToken.safeTransfer(address(msg.sender), luckyDrawInfo.prizeAmount);
        }

        claimRewardInfo[_luckyDrawId][msg.sender] = true;
    }



    //The LuckyDraw. Draw the winning numbers
    function drawWinningNumber(uint256 _luckyDrawId) public onlyOwner {
        LuckyDrawInfo storage luckyDrawInfo = allLuckyDraw[_luckyDrawId];
        require(block.timestamp >= luckyDrawInfo.endTime, "Error: The LuckyDraw is not over yet");
        require(luckyDrawInfo.status == Status.Open, "Error: LuckyDraw status error");

        if (luckyDrawInfo.player.length >= luckyDrawInfo.minPlayerSize) {
            luckyDrawInfo.status = Status.Closed;
            requestId = randomGenerator.getRandomNumber(_luckyDrawId);
            emit RequestNumbers(_luckyDrawId, requestId);
        } else {
            prizeToken.safeTransfer(address(msg.sender), luckyDrawInfo.prizeAmount);
            luckyDrawInfo.status = Status.Completed;
            emit LuckyDrawClose(_luckyDrawId);
        }
    }


    //LuckyDraw: called by random number contract: returns a random number
    function numbersDrawn(uint256 _luckyDrawId, bytes32 _requestId, uint256 _randomNumber) public onlyRandomGenerator() {
        LuckyDrawInfo storage luckyDrawInfo = allLuckyDraw[_luckyDrawId];
        require(luckyDrawInfo.status == Status.Closed, "Error: LuckyDraw status error");
        if (requestId == _requestId) {
            luckyDrawInfo.winner = luckyDrawInfo.player[_randomNumber];
            luckyDrawInfo.status = Status.Completed;
        }
        emit LuckyDrawClose(_luckyDrawId);
    }

    //getPlayerLength
    function getPlayerLength(uint256 _luckyDrawId) public view returns (uint256){
        return allLuckyDraw[_luckyDrawId].player.length;
    }


    //Checks if a player has pledged to participate in a draw
    function checkStake(address _player, uint256 _luckyDrawId) public view returns (bool){
        LuckyDrawInfo storage luckyDrawInfo = allLuckyDraw[_luckyDrawId];
        for (uint i = 0; i < luckyDrawInfo.player.length; i++) {
            if (luckyDrawInfo.player[i] == _player) {
                return true;
            }
        }
        return false;
    }

}
