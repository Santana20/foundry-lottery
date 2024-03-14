// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/**
 * @title Raffle Contract
 * @author Sebastian Contreras
 * @notice This contract is for creating a sample raffle.
 * @dev Learning about implementation of Chainlink VRF & Chainlink Automation.
 */
contract Raffle {
    error Raffle_NotEnoughEthSent();

    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval;
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;

    /* Events */
    event EnteredRaffle(address indexed player);

    constructor(uint256 _entranceFee, uint256 interval) {
        i_entranceFee = _entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
    }

    function pickWinner() external {
        // check to sse if enough time has passed
        if ((block.timestamp - s_lastTimeStamp) < i_interval) {
            revert();
        }
    }

    function enterRaffle() public payable {
        if(msg.value < i_entranceFee) {
            revert Raffle_NotEnoughEthSent();
        }
        
        s_players.push(payable(msg.sender));
        emit EnteredRaffle(msg.sender);
    }

    /* Getter Functions */

    function getEntranceFee() external view returns(uint256) {
        return i_entranceFee;
    }
}
