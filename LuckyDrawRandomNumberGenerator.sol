//SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@chainlink/contracts/src/v0.6/VRFConsumerBase.sol";
import "./ILuckyDraw.sol";


contract LuckyDrawRandomNumberGenerator is VRFConsumerBase {

    bytes32 internal keyHash;
    uint256 internal fee;
    address internal requester;
    uint256 public randomResult;
    uint256 public currentLuckyDrawId;

    address public luckyDraw;

    modifier onlyLuckyDraw() {
        require(
            msg.sender == luckyDraw,
            "Only LuckyDraw can call function"
        );
        _;
    }

    constructor(
        address _vrfCoordinator,
        address _linkToken,
        address _luckyDraw,
        bytes32 _keyHash,
        uint256 _fee
    )
    VRFConsumerBase(
        _vrfCoordinator,
        _linkToken
    ) public
    {
        keyHash = _keyHash;
        fee = _fee;
        luckyDraw = _luckyDraw;
    }

    /**
     * Requests randomness from a user-provided seed
     */
    function getRandomNumber(uint256 luckyDrawId) public onlyLuckyDraw() returns (bytes32 requestId)
    {
        require(keyHash != bytes32(0), "Must have valid key hash");
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK - fill contract with faucet");
        requester = msg.sender;
        currentLuckyDrawId = luckyDrawId;
        return requestRandomness(keyHash, fee);
    }

    /**
     * Callback function used by VRF Coordinator
     */
    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        ILuckyDraw(requester).numbersDrawn(
            currentLuckyDrawId,
            requestId,
            randomResult
        );
        randomResult = randomness;
    }
}