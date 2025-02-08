// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {console} from "forge-std/Console.sol";
import {Test} from "forge-std/Test.sol";

import {MyGovernor} from "../src/MyGovernor.sol";
import {Box} from "../src/Box.sol";
import {GovToken} from "../src/GovToken.sol";
import {TimeLock} from "../src/TimeLock.sol";

contract MyGovernorTest is Test {
    MyGovernor governor;
    Box box;
    GovToken govToken;
    TimeLock timelock;

    address USER = makeAddr("user");
    uint256 INITIAL_SUPPLY = 100 ether;

    address[] PROPOSERS;
    address[] EXECUTORS;

    address[] TARGETS;
    uint256[] VALUES;
    bytes[] CALLDATAS;

    uint256 constant MIN_DELAY = 1 hours;
    uint256 constant VOTING_DELAY = 1;
    uint256 constant VOTING_PERIOD = 7 days;

    function setUp() public {
        govToken = new GovToken();
        govToken.mint(USER, INITIAL_SUPPLY);

        vm.startPrank(USER);
        govToken.delegate(USER);
        timelock = new TimeLock(MIN_DELAY, PROPOSERS, EXECUTORS);
        governor = new MyGovernor(govToken, timelock);

        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        bytes32 executorRole = timelock.EXECUTOR_ROLE();
        bytes32 adminRole = timelock.TIMELOCK_ADMIN_ROLE();

        timelock.grantRole(proposerRole, address(governor));
        timelock.grantRole(executorRole, address(0));
        timelock.revokeRole(adminRole, USER);
        vm.stopPrank();

        box = new Box();
        box.transferOwnership(address(timelock));
    }

    function testCantUpdateBoxWithoutGovernance() public {
        vm.expectRevert();
        box.store(42);
    }

    function testGovernanceUpdatesBox() public {
        uint256 valueToStore = 42;

        string memory description = "Store 42 in the box";
        bytes memory encodedFunctionCall = abi.encodeWithSignature("store(uint256)", valueToStore);

        VALUES.push(0);
        CALLDATAS.push(encodedFunctionCall);
        TARGETS.push(address(box));

        // Propose
        uint256 proposalId = governor.propose(TARGETS, VALUES, CALLDATAS, description);

        // View the State of the proposal
        uint256 state = uint256(governor.state(proposalId));
        // It should be proposed
        console.log("State: ", state);

        vm.warp(block.timestamp + VOTING_DELAY + 1);
        vm.roll(block.number + VOTING_DELAY + 1);

        // Vote
        string memory reason = "Vote for the box";
        uint8 voteWay = 1;

        vm.prank(USER);
        governor.castVoteWithReason(proposalId, voteWay, reason);

        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        vm.roll(block.number + VOTING_PERIOD + 1);

        // Queue
        bytes32 descriptionHash = keccak256(abi.encodePacked(description));
        governor.queue(TARGETS, VALUES, CALLDATAS, descriptionHash);

        // Execute
        vm.warp(block.timestamp + MIN_DELAY + 1);
        vm.roll(block.number + MIN_DELAY + 1);

        governor.execute(TARGETS, VALUES, CALLDATAS, descriptionHash);

        assert(box.getNumber() == valueToStore);
    }
}
