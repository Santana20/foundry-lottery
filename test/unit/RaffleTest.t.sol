// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffleTest is Test {
    /* Events */
    event EnteredRaffle(address indexed player);

    Raffle raffle;
    HelperConfig helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();

        (raffle, helperConfig) = deployer.run();

        (
            entranceFee,
            interval,
            vrfCoordinator,
            gasLane,
            subscriptionId,
            callbackGasLimit,
            ,
        ) = helperConfig.activeNetworkConfig();

        vm.deal(PLAYER, STARTING_USER_BALANCE);
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    /* Enter Raffle */

    function testRaffleRevertsWhenYouDontPayEnough() public {
        // Arrange
        vm.prank(PLAYER);

        // Act / Assert
        vm.expectRevert(Raffle.Raffle__NotEnoughEthSent.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayerWhenTheyEnter() public {
        // Arrange
        vm.prank(PLAYER);

        // Act
        raffle.enterRaffle{value: entranceFee}();
        address playerRecorder = raffle.getPlayer(0);
        // Assert
        assert(playerRecorder == PLAYER);
    }
    function testRaffleEmitsEventOnEntrance() public {
        // Arrange
        vm.prank(PLAYER);

        // Act / Assert
        vm.expectEmit(true, false, false, false, address(raffle));
        emit EnteredRaffle(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testRaffleCantEnterWhenRaffleIsCalculating() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        // Act / Assert
        
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

    }

    /* CheckUpKeep */

    function test_CheckUpKeep_ShouldReturnFalse_WhenItHasNoBalance() public {
        //setUp
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        //execution
        (bool upkeepNeeded,) = raffle.checkUpKeep("");

        //assert
        assert(!upkeepNeeded);
    }

    function test_CheckUpKeep_ShouldReturnFalse_WhenRaffleIsNotOpen() public {
        //setUp
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        //execution
        (bool upkeepNeeded,) = raffle.checkUpKeep("");

        //assert
        assert(!upkeepNeeded);
    }

    function test_CheckUpKeep_ShouldReturnsFalse_WhenEnoughTimeHasntPassed() public {
        //setUp
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        //execution
        (bool upkeepNeeded,) = raffle.checkUpKeep("");

        //assert
        assert(!upkeepNeeded);
    }

    function test_CheckUpKeep_ShouldReturnsTrue_WhenParametersAreGood() public {
        //setUp
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        //execution
        (bool upkeepNeeded,) = raffle.checkUpKeep("");

        //assert
        assert(upkeepNeeded);
    }

    /* PerformUpKeep */

    function test_PerformUpKeep_ShouldOnlyRun_WhenCheckUpKeepIsTrue() public {
        //setUp
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        //execution - this should run without problem
        raffle.performUpkeep("");
        //assert
    }

    function test_PerformUpKeep_ShouldReverts_WhenCheckUpKeepIsFalse() public {
        //setUp
        uint256 currentBalance = address(raffle).balance; // be zero
        uint256 numPlayers = 0;
        Raffle.RaffleState raffleState = raffle.getRaffleState();

        //execution, assert
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                currentBalance,
                numPlayers,
                raffleState
            )
        );
        raffle.performUpkeep("");
    }

    function test_PerformUpKeep_ShouldUpdatesRaffleStateAndEmitsRequestId_WhenItExecCorrectly() 
    public raffleEnteredAndTimePassed {
        //setUp
        vm.recordLogs();
        
        //execution
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        Raffle.RaffleState rState = raffle.getRaffleState();
        //assert
        console.log(uint256(requestId));
        assert(uint256(requestId) > 0);
        assert(uint256(rState) == uint256(Raffle.RaffleState.CALCULATING));
    }

    /* fulfillRandomWords */

    function test_FulFillRandomWords_ShouldOnlyBeCalled_WhenPerformUpKeepWasCalled(
        uint256 randomRequestId
    ) public raffleEnteredAndTimePassed skipFork {
        //setUp
        vm.expectRevert("nonexistent request");
        
        //execution - assert
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );
    }

    function test_FulfillRandomWords_ShouldPicksAWinnerResetsAndSendsMony_WhenExec() 
    public raffleEnteredAndTimePassed skipFork {
        //setUp
        uint256 additionalEntrants = 5;
        uint256 startingIndex = 1;
        for(uint256 i = startingIndex; i < startingIndex + additionalEntrants; i++) {
            address player = address(uint160(i));
            hoax(player, STARTING_USER_BALANCE);
            raffle.enterRaffle{value: entranceFee}();
        }

        uint256 prize = entranceFee * (additionalEntrants + 1);

        //execution
        /// get requestId
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        uint256 previousTimeStamp = raffle.getLastTimeStamp();

        /// pretend to be chainlink vrf to get random number & pick winner.
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        //assert
        assert(raffle.getRecentWinner() != address(0));
        assert(uint256(raffle.getRaffleState()) == uint256(Raffle.RaffleState.OPEN));
        assert(raffle.getLengthOfPlayers() == 0);
        assert(raffle.getLastTimeStamp() > previousTimeStamp);
        assert(raffle.getRecentWinner().balance == (STARTING_USER_BALANCE + prize - entranceFee));
    }

    modifier raffleEnteredAndTimePassed() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    modifier skipFork() {
        if(block.chainid != 31337) {
            return;
        }
        _;
    }
}