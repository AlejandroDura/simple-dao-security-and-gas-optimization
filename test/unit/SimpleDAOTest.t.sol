// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {SimpleDAO} from "src/v2/SimpleDAO.sol";
import {MyTokenVotes} from "src/v2/MyTokenVotes.sol";
import {GovernedContract} from "src/aux/GovernedContract.sol";

contract SimpleDAOTest is Test {
    uint256 constant NUM_USERS = 100;
    uint256 constant INITIAL_BALANCE = 100 ether;
    uint256 constant INITIAL_TOKEN_BALANCE = 1e18;
    uint256 constant DAYS_DEADLINE = 3 days;
    uint256 private constant QUORUM_BP = 1000; //10%

    bytes callData;
    bytes32 description;
    uint256 proposalId;

    address userA;
    address userB;
    address userC;
    address userNoFounds;
    address userNoTokens;
    address userNotEnoughFunds;

    MyTokenVotes myToken;
    SimpleDAO dao;
    GovernedContract governedContract;

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
        dao = new SimpleDAO(address(myToken));

        //DEPLOY GOVERNED CONTRACT
        governedContract = new GovernedContract(address(dao));
    }

    modifier createProposal() {
        vm.roll(block.number + 1);

        callData = abi.encodeWithSignature(
            "allowTarget(address)",
            address(governedContract)
        );
        description = keccak256("allow new target");

        vm.prank(userA);
        proposalId = dao.createProposal(address(dao), callData, description);

        _;
    }

    //----------CREATE PROPOSAL---------//
    function testCreateProposal_CanNotProposeWithNonWhitelistedTarget() public {
        vm.roll(block.number + 1);

        bytes memory callDataNotAllowedTarget = abi.encodeWithSignature(
            "increaseCounter(uint256)",
            1
        );
        bytes32 descriptionNotAllowedTarget = keccak256("governed contract");

        vm.expectRevert("Target not whitelisted");
        vm.prank(userA);
        proposalId = dao.createProposal(
            address(governedContract),
            callDataNotAllowedTarget,
            descriptionNotAllowedTarget
        );
    }

    function testCreateProposal_CanNotProposeWithNonAllowedDaoSelector()
        public
    {
        vm.roll(block.number + 1);

        bytes memory callDataNotAllowedSelector = abi.encodeWithSignature(
            "execute(uint256)",
            0
        );
        bytes32 descriptionNotAllowedSelector = keccak256("dao contract");

        vm.expectRevert("Not allowed selector");
        vm.prank(userA);
        proposalId = dao.createProposal(
            address(dao),
            callDataNotAllowedSelector,
            descriptionNotAllowedSelector
        );
    }

    function testCreateProposal_CallDataTooShort() public {
        vm.roll(block.number + 1);

        bytes memory callDataShort = abi.encodePacked(bytes3(0x001122));
        bytes32 descriptionCallDataShort = keccak256("dao contract");

        vm.expectRevert("callData too short");
        vm.prank(userA);
        proposalId = dao.createProposal(
            address(dao),
            callDataShort,
            descriptionCallDataShort
        );
    }

    function testCreateProposal_StorageInfo() public createProposal {
        SimpleDAO.Proposal memory proposal;
        proposal = dao.getProposal(proposalId);
        (uint256 voteYes, uint256 voteNo, uint256 totalSupply) = dao
            .getVoteInfo(proposalId);

        assert(proposal.proposer == userA);
        assert(proposal.target == address(dao));
        assert(proposal.deadline == block.timestamp + DAYS_DEADLINE);
        assert(proposal.snapshotBlock == block.number - 1);
        assert(keccak256(proposal.callData) == keccak256(callData));
        assert(proposal.description == description);
        assert(proposal.executed == false);

        assert(voteYes == 0);
        assert(voteNo == 0);
        assert(
            totalSupply == myToken.getPastTotalSupply(proposal.snapshotBlock)
        );
    }

    //----------WHITELIST-----------//
    function testWhitelist_DaoAllowedSelectors() public view {
        bytes4 allowTargetSelector = bytes4(
            keccak256(bytes("allowTarget(address)"))
        );
        bytes4 disallowTargetSelector = bytes4(
            keccak256(bytes("disallowTarget(address)"))
        );

        bool allowed = dao.getAllowedSelector(
            address(dao),
            allowTargetSelector
        );
        allowed =
            allowed &&
            dao.getAllowedSelector(address(dao), disallowTargetSelector);

        assert(allowed == true);
    }

    function testWhitelist_OnlyDaoCanAddNewTarget() public {
        vm.expectRevert("Only dao can call this function");
        dao.allowTarget(address(123456));
    }

    function testWhitelist_NotAllowZeroTarget() public {
        vm.expectRevert("Can't add zero as target");
        vm.prank(address(dao));
        dao.allowTarget(address(0));
    }

    function testWhitelist_CanNotAddDao() public {
        vm.expectRevert("Can't add DAO as target");
        vm.prank(address(dao));
        dao.allowTarget(address(dao));
    }

    function testWhitelist_AddNewTargetSuccessfully() public {
        address newTarget = address(12345);

        vm.prank(address(dao));
        dao.allowTarget(newTarget);

        assert(dao.getTargetAllowed(newTarget) == true);
    }

    function testWhiteList_OnlyDaoCanDisallow() public {
        address targetAddress = address(12345);

        vm.expectRevert("Only dao can call this function");
        dao.disallowTarget(targetAddress);
    }

    function testWhiteList_CanNotDisallowNonExistentTarget() public {
        address targetAddress = address(0);

        vm.expectRevert("Target does not exist or is banned");
        vm.prank(address(dao));
        dao.disallowTarget(targetAddress);
    }

    function testWhiteList_DisallowAllowedTarget() public {
        address targetAddress = address(12345);

        vm.prank(address(dao));
        dao.allowTarget(targetAddress);

        vm.prank(address(dao));
        dao.disallowTarget(targetAddress);

        assert(dao.getTargetAllowed(targetAddress) == false);
    }
    //------------VOTE PROPOSAL-----------///

    function testVoteProposal_ProposalIdOutOfRange() public createProposal {
        vm.expectRevert("Proposal index out of bounds!");
        vm.prank(userA);
        dao.vote(1, true);
    }

    function testVoteProposal_ProposalExpired() public createProposal {
        vm.warp(block.timestamp + DAYS_DEADLINE);
        vm.expectRevert("Proposal expired!");
        vm.prank(userA);
        dao.vote(proposalId, true);
    }

    function testVoteProposal_UserHasAlreadyVote() public createProposal {
        vm.prank(userA);
        dao.vote(proposalId, true);

        vm.expectRevert(
            "You have already voted. You cant vote more than one time!"
        );
        vm.prank(userA);
        dao.vote(proposalId, true);
    }

    function testVoteProposal_UserWithNoTokens() public createProposal {
        vm.expectRevert("Yo dont have tokens to vote");
        vm.prank(userNoTokens);
        dao.vote(proposalId, true);
    }

    function testVoteProposal_StorageInfo() public createProposal {
        vm.prank(userA);
        dao.vote(proposalId, true);

        vm.prank(userB);
        dao.vote(proposalId, false);

        vm.prank(userA);
        bool hasVoted = dao.getHasVoted(proposalId);

        (uint256 voteYes, uint256 voteNo, ) = dao.getVoteInfo(proposalId);

        assert(voteYes == myToken.balanceOf(userA));
        assert(voteNo == myToken.balanceOf(userB));
        assert(hasVoted = true);
    }

    //---------EXECUTE PROPOSAL----------//

    function testExecuteProposal_QuorumNotMeet() public createProposal {
        vm.prank(userNotEnoughFunds);
        dao.vote(proposalId, true);

        vm.expectRevert("Quorum not reached");
        vm.prank(userA);
        dao.execute(proposalId);
    }

    function testExecuteProposal_ProposalIdOutRange() public createProposal {
        vm.prank(userA);
        dao.vote(proposalId, true);

        vm.expectRevert("Proposal index out of bounds!");
        vm.prank(userA);
        dao.execute(1);
    }

    function testExecuteProposal_ProposalDeadlineNotFinished()
        public
        createProposal
    {
        vm.prank(userA);
        dao.vote(proposalId, true);

        vm.expectRevert("The proposal voting has not finished!");
        vm.prank(userA);
        dao.execute(0);
    }

    function testExecuteProposal_ProposalNotAproved() public createProposal {
        vm.prank(userA);
        dao.vote(proposalId, false);

        vm.warp(block.timestamp + DAYS_DEADLINE);

        vm.expectRevert("Proposal not aproved");
        vm.prank(userA);
        dao.execute(0);
    }

    function testExecuteProposal_ProposalCanNotBeRexecuted()
        public
        createProposal
    {
        vm.prank(userA);
        dao.vote(proposalId, true);

        vm.warp(block.timestamp + DAYS_DEADLINE);

        vm.prank(userA);
        dao.execute(0);

        vm.expectRevert(
            "The proposal has already been executed! Can not reexecute again"
        );
        vm.prank(userA);
        dao.execute(0);
    }

    function testExecuteProposal_ProposalExecutedSuccessfully()
        public
        createProposal
    {
        vm.prank(userA);
        dao.vote(proposalId, true);

        vm.warp(block.timestamp + DAYS_DEADLINE);

        vm.prank(userA);
        dao.execute(0);
    }

    function testExecuteProposal_AddNewTargetProposalExecuted()
        public
        createProposal
    {
        vm.prank(userA);
        dao.vote(proposalId, true);

        vm.warp(block.timestamp + DAYS_DEADLINE);

        vm.prank(userA);
        dao.execute(0);

        assert(dao.getTargetAllowed(address(governedContract)) == true);
    }
}
