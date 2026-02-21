// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {
    ReentrancyGuard
} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IGovernanceToken {
    function balanceOf(address account) external view returns (uint256);
    function getPastVotes(
        address account,
        uint256 blockNumber
    ) external view returns (uint256);
    function getPastTotalSupply(
        uint256 timepoint
    ) external view returns (uint256);
}

contract SimpleDAO_Final is ReentrancyGuard {
    struct Proposal {
        address proposer; // 20 bytes
        uint64 deadline; // 8 bytes
        address target; // 20 bytes
        uint64 snapshotBlock; // 8 bytes,
        bool executed; // 1 bytes
        bytes32 description; // 32 bytes
        uint256 voteYes; // 32 bytes
        uint256 voteNo; // 32 bytes
        bytes callData; //dynamic
    }

    uint256 private constant QUORUM_BP = 1000; //10%
    uint256 public constant VOTING_PERIOD = 3 days;

    IGovernanceToken public immutable token;
    Proposal[] public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    mapping(address => bool) public allowedTargets;
    mapping(address => mapping(bytes4 => bool)) private allowedSelectors;

    event ProposalCreated(
        uint256 indexed id,
        address proposer,
        bytes32 description
    );
    event Voted(uint256 indexed id, address voter, bool support);
    event Executed(uint256 indexed id);

    modifier onlyWhitelisted(address target, bytes calldata callData) {
        require(callData.length >= 4, "callData too short");

        if (target == address(this)) {
            bytes4 selector = bytes4(callData[:4]);
            require(allowedSelectors[target][selector], "Not allowed selector");
        } else {
            require(allowedTargets[target]);
        }

        _;
    }

    constructor(address _token) {
        token = IGovernanceToken(_token);

        bytes4 allowTargetSelector = bytes4(
            keccak256(bytes("allowTarget(address)"))
        );
        bytes4 disallowTargetSelector = bytes4(
            keccak256(bytes("disallowTarget(address)"))
        );

        allowedSelectors[address(this)][allowTargetSelector] = true;
        allowedSelectors[address(this)][disallowTargetSelector] = true;
    }

    function allowTarget(address desiredTarget) external {
        require(msg.sender == address(this), "Only dao can call this function");
        require(desiredTarget != address(0), "Can't add zero as target");
        require(desiredTarget != address(this), "Can't add DAO as target");

        allowedTargets[desiredTarget] = true;
    }

    function disallowTarget(address desiredTarget) external {
        require(msg.sender == address(this), "Only dao can call this function");
        require(desiredTarget != address(0), "Can't ban zero as target");
        require(
            allowedTargets[desiredTarget],
            "Target does not exist or is banned"
        );

        allowedTargets[desiredTarget] = false;
    }

    function createProposal(
        address _target,
        bytes calldata _callData,
        bytes32 _description
    ) external onlyWhitelisted(_target, _callData) returns (uint256) {
        require(
            token.getPastVotes(msg.sender, block.number - 1) > 0,
            "Only holders can propose"
        );

        proposals.push(
            Proposal({
                proposer: msg.sender,
                target: _target,
                deadline: uint64(block.timestamp + VOTING_PERIOD),
                snapshotBlock: uint64(block.number - 1),
                callData: _callData,
                description: _description,
                voteYes: 0,
                voteNo: 0,
                executed: false
            })
        );

        uint256 id = proposals.length - 1;

        emit ProposalCreated(id, msg.sender, _description);

        return id;
    }

    function vote(uint256 proposalId, bool support) external {
        require(proposalId < proposals.length, "Proposal index out of bounds!");

        Proposal storage proposal = proposals[proposalId];

        require(block.timestamp < proposal.deadline, "Proposal expired!");

        require(
            !hasVoted[proposalId][msg.sender],
            "You have already voted. You cant vote more than one time!"
        );

        uint256 voterBalance = token.getPastVotes(
            msg.sender,
            proposal.snapshotBlock
        );
        require(voterBalance > 0, "Yo dont have tokens to vote");

        if (support) {
            proposal.voteYes += voterBalance;
        } else {
            proposal.voteNo += voterBalance;
        }

        hasVoted[proposalId][msg.sender] = true;
        emit Voted(proposalId, msg.sender, support);
    }

    function execute(uint256 proposalId) external nonReentrant {
        require(proposalId < proposals.length, "Proposal index out of bounds!");

        Proposal storage proposal = proposals[proposalId];

        require(
            !proposal.executed,
            "The proposal has already been executed! Can not reexecute again"
        );

        require(
            block.timestamp >= proposal.deadline,
            "The proposal voting has not finished!"
        );

        require(proposal.voteYes > proposal.voteNo, "Proposal not aproved");

        uint256 TotalSupply = token.getPastTotalSupply(proposal.snapshotBlock);
        require(
            proposal.voteYes + proposal.voteNo >=
                (TotalSupply * QUORUM_BP) / 10_000,
            "Quorum not reached"
        );

        proposal.executed = true;

        (bool success, ) = proposal.target.call(proposal.callData);
        require(success, "The target call has failed!");

        emit Executed(proposalId);
    }

    function getProposal(uint256 id) external view returns (Proposal memory) {
        return proposals[id];
    }

    function totalProposals() external view returns (uint256) {
        return proposals.length;
    }
}
