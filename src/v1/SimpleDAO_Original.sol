// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IGovernanceToken {
    function balanceOf(address account) external view returns (uint256);
    function getPastVotes(
        address account,
        uint256 blockNumber
    ) external view returns (uint256);
}

contract SimpleDAO_Original {
    struct Proposal {
        address proposer; // 20 bytes
        address target; // 20 bytes
        bytes callData; // dynamic
        string description; // dynamic
        uint256 voteYes; // 32 bytes
        uint256 voteNo; // 32 bytes
        uint256 deadline; // 32 bytes
        bool executed; // 1 bytes
    }

    IGovernanceToken public token;
    Proposal[] public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    uint256 public constant VOTING_PERIOD = 3 days;

    event ProposalCreated(
        uint256 indexed id,
        address proposer,
        string description
    );

    event Voted(uint256 indexed id, address voter, bool support);
    event Executed(uint256 indexed id);

    constructor(address _token) {
        token = IGovernanceToken(_token);
    }

    function createProposal(
        address _target,
        bytes calldata _callData,
        string memory _description
    ) public returns (uint256) {
        require(token.balanceOf(msg.sender) > 0, "Only holders can propose");

        proposals.push(
            Proposal({
                proposer: msg.sender,
                target: _target,
                deadline: block.timestamp + VOTING_PERIOD,
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

    function vote(uint256 proposalId, bool support) public {
        require(proposalId < proposals.length, "Proposal index out of bounds!");

        uint256 voterBalance = token.balanceOf(msg.sender);

        require(voterBalance > 0, "Yo dont have tokens to vote");
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp < proposal.deadline, "Proposal expired!");
        require(
            !hasVoted[proposalId][msg.sender],
            "You have already voted. You cant vote more than one time!"
        );

        if (support) {
            proposal.voteYes += voterBalance;
        } else {
            proposal.voteNo += voterBalance;
        }

        hasVoted[proposalId][msg.sender] = true;
        emit Voted(proposalId, msg.sender, support);
    }

    function execute(uint256 proposalId) public {
        require(proposalId < proposals.length, "Proposal index out of bounds!");

        Proposal storage proposal = proposals[proposalId];

        require(
            block.timestamp >= proposal.deadline,
            "The proposal voting has not finished!"
        );
        require(
            !proposal.executed,
            "The proposal has already been executed! Can not reexecute again"
        );
        require(proposal.voteYes > proposal.voteNo, "Proposal not aproved");

        (bool success, ) = proposal.target.call(proposal.callData);
        require(success, "The target call has failed!");

        proposal.executed = true;

        emit Executed(proposalId);
    }

    function getProposal(uint256 id) public view returns (Proposal memory) {
        return proposals[id];
    }

    function totalProposals() public view returns (uint256) {
        return proposals.length;
    }
}
