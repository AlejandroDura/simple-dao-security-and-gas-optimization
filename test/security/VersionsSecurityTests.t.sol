// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {SimpleDAO_Original} from "src/v1/SimpleDAO_Original.sol";
import {SimpleDAO} from "src/v2/SimpleDAO.sol";
import {MyTokenVotes} from "src/v2/MyTokenVotes.sol";
import {GovernedContract} from "src/aux/GovernedContract.sol";
import {Malicious} from "src/aux/Malicious.sol";

contract VersionsSecurityTests is Test {
    uint256 constant NUM_USERS = 100;

    address userA;
    address userB;
    address userC;
    address userNoFounds;
    address userNoTokens;
    address userNotEnoughFunds;

    bytes callData;
    bytes32 description;
    uint256 proposalId;

    MyTokenVotes myToken;
    SimpleDAO_Original daoV1;
    SimpleDAO daoV2;
    GovernedContract governedContractV1;
    GovernedContract governedContractV2;
    Malicious maliciousV1;
    Malicious maliciousV2;

    uint256 constant INITIAL_BALANCE = 100 ether;
    uint256 constant INITIAL_TOKEN_BALANCE = 1e18;
    uint256 constant DAYS_DEADLINE = 3 days;

    mapping(uint256 => bytes32) proposalIdToDescription;

    function setUp() public {
        //Create a single user
        userA = vm.addr(0x1);
        userB = vm.addr(0x2);
        userC = vm.addr(0x3);
        userNoFounds = vm.addr(0x4);
        userNoTokens = vm.addr(0x5);
        userNotEnoughFunds = vm.addr(0x6);
        vm.deal(userA, INITIAL_BALANCE);
        vm.deal(userB, INITIAL_BALANCE);
        vm.deal(userC, INITIAL_BALANCE);
        vm.deal(userNoTokens, INITIAL_BALANCE);

        //DEPLOY THE TOKEN
        myToken = new MyTokenVotes();

        //Mint all users
        myToken.mint(userA, INITIAL_TOKEN_BALANCE);
        myToken.mint(userB, INITIAL_TOKEN_BALANCE);
        myToken.mint(userC, INITIAL_TOKEN_BALANCE);
        myToken.mint(userNotEnoughFunds, 0.01 * 1e18);

        //Delegate users
        vm.prank(userA);
        myToken.delegate(userA);

        vm.prank(userB);
        myToken.delegate(userB);

        vm.prank(userC);
        myToken.delegate(userC);

        vm.prank(userNoTokens);
        myToken.delegate(userNoTokens);

        vm.prank(userNotEnoughFunds);
        myToken.delegate(userNotEnoughFunds);

        //DEPLOY DAO
        daoV1 = new SimpleDAO_Original(address(myToken));
        daoV2 = new SimpleDAO(address(myToken));

        //DEPLOY GOVERNED CONTRACT
        governedContractV1 = new GovernedContract(address(daoV1));
        governedContractV2 = new GovernedContract(address(daoV2));

        //DEPLOY MALICIOUS
        maliciousV1 = new Malicious(address(daoV1));
        maliciousV2 = new Malicious(address(daoV2));
    }

    modifier createProposalV1() {
        vm.roll(block.number + 1);

        callData = abi.encodeWithSignature("increaseCounter(uint256)", 1);
        description = keccak256("increase counter by 1");

        vm.prank(userA);
        proposalId = daoV1.createProposal(
            address(governedContractV1),
            callData,
            "increase counter by 1"
        );

        _;
    }

    modifier createProposalV2() {
        vm.roll(block.number + 1);

        callData = abi.encodeWithSignature(
            "allowTarget(address)",
            address(governedContractV2)
        );
        description = keccak256("allow new target");

        vm.prank(userA);
        proposalId = daoV2.createProposal(
            address(daoV2),
            callData,
            description
        );

        _;
    }

    function testOnlyWhitelistedTargetV2() public {
        address targetV2 = address(governedContractV2);
        bytes memory callDataV2 = abi.encodeWithSignature(
            "increaseCounter(uint256)",
            1
        );
        bytes32 descriptionV2 = keccak256("increase counter by 1");

        vm.prank(userA);
        vm.expectRevert("Target not whitelisted");
        daoV2.createProposal(targetV2, callDataV2, descriptionV2);
    }

    function testVotingPowerManipulationV1() public createProposalV1 {
        //Proposal data
        SimpleDAO_Original.Proposal memory proposal;

        //Move one block forward
        vm.roll(block.number + 1);

        //Vote with userA
        uint256 userAVoteBalance = myToken.balanceOf(userA);
        vm.prank(userA);
        daoV1.vote(proposalId, true);

        // //Transfer 0.5 MT from userA to userNoTokens
        vm.prank(userA);
        myToken.transfer(userNoTokens, 0.5 ether);
        uint256 userNoTokensBalance = myToken.balanceOf(userNoTokens);

        //Vote with userNoTokens
        vm.prank(userNoTokens);
        daoV1.vote(proposalId, true);

        proposal = daoV1.getProposal(proposalId);
        uint256 finalYesVotes = userAVoteBalance + userNoTokensBalance;
        assertEq(proposal.voteYes, finalYesVotes);
    }

    function testVotingPowerManipulationV2() public createProposalV2 {
        //Move one block forward
        vm.roll(block.number + 1);

        //Vote with userA
        vm.prank(userA);
        daoV2.vote(proposalId, true);

        // //Transfer 0.5 MT from userA to userNoTokens
        vm.prank(userA);
        myToken.transfer(userNoTokens, 0.5 ether);

        //Vote with userNoTokens
        vm.prank(userNoTokens);
        vm.expectRevert("Yo dont have tokens to vote");
        daoV2.vote(proposalId, true);
    }

    function testMissQuorumV1() public createProposalV1 {
        //Move one block forward
        vm.roll(block.number + 1);

        //Mint user no token
        myToken.mint(userNoTokens, 0.1 * 10e18);

        //vote
        vm.prank(userNoTokens);
        daoV1.vote(proposalId, true);

        //move time forward
        vm.warp(block.timestamp + DAYS_DEADLINE);

        //execute
        vm.prank(userNoTokens);
        daoV1.execute(proposalId);
    }

    function testQuorumFailV2() public createProposalV2 {
        vm.roll(block.number + 1);

        //Try to vote and execute with not enough vote tokens.
        vm.prank(userNotEnoughFunds);
        daoV2.vote(proposalId, true);

        //move time forward
        vm.warp(block.timestamp + DAYS_DEADLINE);

        //Try execute
        vm.expectRevert("Quorum not reached");
        vm.prank(userA);
        daoV2.execute(proposalId);
    }

    function testQuorumMeetV2() public createProposalV2 {
        vm.roll(block.number + 1);

        //Vote with userA (enough tokens)
        vm.prank(userA);
        daoV2.vote(proposalId, true);

        //Move time forward
        vm.warp(block.timestamp + DAYS_DEADLINE);

        //Execute proposal
        vm.prank(userA);
        daoV2.execute(proposalId);
    }

    function testReentrancy_VulnerableV1() public {
        address target = address(maliciousV1);
        bytes memory callData = maliciousV1.encodedAttackCall();
        string memory description = "desc";
        uint256 proposalId;

        //Move one block forward
        vm.roll(block.number + 1);

        //Create proposal
        vm.prank(userA);
        proposalId = daoV1.createProposal(target, callData, description);

        //Set proposal in malicious contract
        maliciousV1.setProposal(proposalId);

        //Vote
        vm.prank(userA);
        daoV1.vote(proposalId, true);

        //Execute proposal
        vm.warp(block.timestamp + 4 days);
        daoV1.execute(proposalId);

        assertGt(maliciousV1.timesEntered(), 1);
        assertEq(maliciousV1.timesEntered(), 2);
    }

    function testReentrancy_PatchedV2() public createProposalV2 {
        vm.roll(block.number + 1);

        //--------WHITELIST MALICIOUS TARGET--------
        address target = address(daoV2);
        bytes memory callData = abi.encodeWithSignature(
            "allowTarget(address)",
            address(maliciousV2)
        );
        bytes32 description = keccak256("allow malicious target");

        vm.prank(userA);
        uint256 proposalId = daoV2.createProposal(
            target,
            callData,
            description
        );

        vm.prank(userA);
        daoV2.vote(proposalId, true);

        vm.warp(block.timestamp + DAYS_DEADLINE);

        vm.prank(userA);
        daoV2.execute(proposalId);

        //------CREATE PROPOSAL WITH MALICIOUS TARGET------
        target = address(maliciousV2);
        callData = maliciousV2.encodedAttackCall();
        description = keccak256("malicious");

        //Move one block forward
        vm.roll(block.number + 1);

        //Create proposal
        vm.prank(userA);
        proposalId = daoV2.createProposal(target, callData, description);

        //Set proposal in malicious contract
        maliciousV2.setProposal(proposalId);

        //Vote
        vm.prank(userA);
        daoV2.vote(proposalId, true);

        //Execute
        vm.warp(block.timestamp + DAYS_DEADLINE);
        vm.expectRevert("The target call has failed!");
        daoV2.execute(proposalId);

        assertEq(maliciousV2.timesEntered(), 0);
    }
}
