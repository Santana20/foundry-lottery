// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script{

    function createSubscriptionUsingConfig() public  returns(uint64) {
        HelperConfig helperConfig = new HelperConfig();
        (
            ,
            ,
            address vrfCoordinator,
            ,
            ,
            ,
            ,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();

        return createSubscription(vrfCoordinator, deployerKey);
    }

    function createSubscription(address vrfCoordinator, uint256 deployerKey) public returns (uint64) {
        console.log("Creating subscription on chainId: ", block.chainid);
        vm.startBroadcast(deployerKey);
        uint64 subId = VRFCoordinatorV2Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();

        console.log("Your sub Id is: ", subId);
        console.log("Please update subscriptionId in HelperConfig");
        return subId;

    }

    function run() external returns(uint64) {

        return createSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script {

    uint96 public constant FUND_AMOUNT = 3 ether;
    uint256 public constant LOCAL_TEST_CHAIN_ID = 31337;

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        (
            ,
            ,
            address vrfCoordinator,
            ,
            uint64 subscriptionId,
            ,
            address linkTokenAddress,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();

        fundSubscription(vrfCoordinator, subscriptionId, linkTokenAddress, deployerKey);
    }

    function fundSubscription(address vrfCoordinator, uint64 subId, address linkTokenAddress, uint256 deployerKey) public  {
        
        console.log("Funding subscription with: chainId:", block.chainid);
        console.log("subscription Id: ", subId);
        console.log("vrfCoordinator: ", vrfCoordinator);
        console.log("linkTokenAddress: ", linkTokenAddress);

        if (block.chainid == LOCAL_TEST_CHAIN_ID) {

            vm.startBroadcast(deployerKey);
            VRFCoordinatorV2Mock(vrfCoordinator).fundSubscription(
                subId,
                FUND_AMOUNT
            );
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(deployerKey);
            LinkToken(linkTokenAddress).transferAndCall(
                vrfCoordinator,
                FUND_AMOUNT,
                abi.encode(subId)
            );
            vm.stopBroadcast();
        }
    }

    function createSubscription(address vrfCoordinator) public returns (uint64) {
        console.log("Creating subscription on chainId: ", block.chainid);
        vm.startBroadcast();
        uint64 subId = VRFCoordinatorV2Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();

        console.log("Your sub Id is: ", subId);
        console.log("Please update subscriptionId in HelperConfig");
        return subId;

    }

    function run() external {

        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {

    uint96 public constant FUND_AMOUNT = 3 ether;

    function addConsumerUsingConfig(address raffle) public {
        HelperConfig helperConfig = new HelperConfig();
        (
            ,
            ,
            address vrfCoordinator,
            ,
            uint64 subscriptionId,
            ,
            ,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();

        addConsumer(raffle, vrfCoordinator, subscriptionId, deployerKey);
    }

    function addConsumer(address raffle, address vrfCoordinator, uint64 subId, uint256 deployerKey) public  {
        console.log("Chain id:", block.chainid);
        console.log("Adding consumer contract:", raffle);
        console.log("vrfCoordinator: ", vrfCoordinator);
        console.log("subscription Id: ", subId);

        vm.startBroadcast(deployerKey);
        VRFCoordinatorV2Mock(vrfCoordinator).addConsumer(
            subId,
            raffle
        );
        vm.stopBroadcast();
    }

    function createSubscription(address vrfCoordinator) public returns (uint64) {
        console.log("Creating subscription on chainId: ", block.chainid);
        vm.startBroadcast();
        uint64 subId = VRFCoordinatorV2Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();

        console.log("Your sub Id is: ", subId);
        console.log("Please update subscriptionId in HelperConfig");
        return subId;

    }

    function run() external {
        address raffle = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        addConsumerUsingConfig(raffle);
    }
}