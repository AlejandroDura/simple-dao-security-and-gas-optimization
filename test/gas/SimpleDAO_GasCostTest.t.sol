// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {SimpleDAO} from "src/v2/SimpleDAO.sol";
import {MyTokenVotes} from "src/v2/MyTokenVotes.sol";
import {GovernedContract} from "src/aux/GovernedContract.sol";

contract SimpleDAO_GasCostTest is Test {
    uint256 constant NUM_USERS = 100;

    address userA;
    address userB;
    address userC;
    address userNoFounds;
    address userNoTokens;

    MyTokenVotes myToken;
    SimpleDAO dao;
    GovernedContract governedContract;

    uint256 constant INITIAL_BALANCE = 100 ether;
    uint256 constant INITIAL_TOKEN_BALANCE = 1e18;
    uint256 constant DAYS_DEADLINE = 3 days;

    mapping(uint256 => string) proposalIdToDescription;

    uint256 proposalTestId;

    function setUp() public {
        //Create a single user
        userA = vm.addr(0x1);
        userB = vm.addr(0x2);
        userC = vm.addr(0x3);
        userNoFounds = vm.addr(0x4);
        userNoTokens = vm.addr(0x5);
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

        //Delegate users
        vm.prank(userA);
        myToken.delegate(userA);

        vm.prank(userB);
        myToken.delegate(userB);

        vm.prank(userC);
        myToken.delegate(userC);

        vm.prank(userNoTokens);
        myToken.delegate(userNoTokens);

        //DEPLOY DAO
        dao = new SimpleDAO(address(myToken));

        //DEPLOY GOVERNED CONTRACT
        governedContract = new GovernedContract(address(dao));

        //----------------PROPOSAL CREATION---------------------//
        address target = address(dao);
        bytes memory callData = abi.encodeWithSignature(
            "allowTarget(address)",
            address(12345)
        );

        //Move one block forward
        vm.roll(block.number + 1);

        bytes32 description = keccak256(
            "Increase counter in governed contract"
        );
        vm.prank(userA);
        proposalTestId = dao.createProposal(target, callData, description);

        vm.roll(block.number + 1);
        vm.prank(userB);
        dao.vote(proposalTestId, true);
    }

    function testGas_CreateProposal() public {
        address target = address(dao);
        bytes memory callData = abi.encodeWithSignature(
            "allowTarget(address)",
            address(12345)
        );

        bytes32 description = keccak256(
            "Increase counter in governed contract"
        );
        vm.prank(userA);
        dao.createProposal(target, callData, description);
    }

    function testGas_Vote() public {
        vm.roll(block.number + 1);

        vm.prank(userA);
        dao.vote(proposalTestId, true);
    }

    function testGas_Execute() public {
        vm.warp(block.timestamp + 4 days);
        vm.prank(userA);
        dao.execute(proposalTestId);
    }
}
