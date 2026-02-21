// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {
    ReentrancyGuard
} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {VoteManager} from "src/v2/VoteManager.sol";

interface IGovernanceToken {
    function getPastVotes(
        address account,
        uint256 blockNumber
    ) external view returns (uint256);
    function getPastTotalSupply(
        uint256 timepoint
    ) external view returns (uint256);
}

/**
 * @title GovernorBase
 * @notice Define la lógica base de un token fungible
 * @dev Governor core functionality. It must be inherited from a child contract to deploy it.
 */
abstract contract GovernorBase is ReentrancyGuard, VoteManager {
    /// @dev The proposal struct data. It represents a proposal in the system.
    struct Proposal {
        address proposer; // 20 bytes
        uint64 deadline; // 8 bytes
        address target; // 20 bytes
        uint64 snapshotBlock; // 8 bytes,
        bool executed; // 1 bytes
        bytes32 description; // 32 bytes
        bytes callData; //dynamic
    }

    /// @dev the allowed votting period time to vote a proposal.
    uint256 private constant VOTING_PERIOD = 3 days;

    /// @dev the token used in the governance.
    IGovernanceToken private immutable i_token;

    /// @dev Proposal storage. Its were all the proposals are stored, indexed by their id.
    Proposal[] private s_proposals;

    /// @dev maps if a user inside a proposal (identified by its proposal id) has voted the proposal.
    mapping(uint256 => mapping(address => bool)) private s_hasVoted;

    /// @dev event used to emmit a proposal creation data.
    event ProposalCreated(
        uint256 indexed id,
        address proposer,
        bytes32 description
    );

    /// @dev event used to emmit a vote data.
    event Voted(uint256 indexed id, address voter, bool support);

    /// @dev event used to emmit a proposal execution data.
    event Executed(uint256 indexed id);

    /**
     * @dev Governor base initialization. It must be called in its child contract.
     * @param _token the token address that we will use in governance.
     */
    constructor(address _token) {
        i_token = IGovernanceToken(_token);
    }

    /**
     * @dev Wrapper function that creates new proposal in the system. It uses a hook _beforePropose to add extra
     * functionality before proposing and the core function _createProposal.
     * @param _target the target contract address that we want to call.
     * @param _callData A bytes string that contains the target function signature and its parameter values encoded.
     * We use this callData to call the target contract function we want.
     * @param _description A proposal hash description.
     * @return uint256 - The proposal id. This is the proposal identifier we can use to interact with the proposal.
     */
    function createProposal(
        address _target,
        bytes calldata _callData,
        bytes32 _description
    ) external returns (uint256) {
        _beforePropose(_target, _callData);
        return _createProposal(_target, _callData, _description);
    }

    /**
     * @dev Create proposal core function.
     */
    function _createProposal(
        address _target,
        bytes calldata _callData,
        bytes32 _description
    ) private returns (uint256) {
        require(
            i_token.getPastVotes(msg.sender, block.number - 1) > 0,
            "Only holders can propose"
        );

        s_proposals.push(
            Proposal({
                proposer: msg.sender,
                target: _target,
                deadline: uint64(block.timestamp + VOTING_PERIOD),
                snapshotBlock: uint64(block.number - 1),
                callData: _callData,
                description: _description,
                executed: false
            })
        );

        uint256 proposalId = s_proposals.length - 1;
        uint256 proposalCreationTokenSupply = i_token.getPastTotalSupply(
            block.number - 1
        );
        _initializeNewProposalVotes(proposalId, proposalCreationTokenSupply);

        emit ProposalCreated(proposalId, msg.sender, _description);

        return proposalId;
    }

    /**
     * @dev Wrapper function that adds possitive or negative votes to the specified proposal.
     * @param _proposalId The id that identifies a proposal in the system.
     * @param _support The parameter that indicates if the player is for or against the proposal.
     */
    function vote(uint256 _proposalId, bool _support) external {
        _vote(_proposalId, _support);
    }

    /**
     * @dev Vote core function. The system uses the player power vote to vote for or against.
     */
    function _vote(uint256 _proposalId, bool _support) private {
        require(
            _proposalId < s_proposals.length,
            "Proposal index out of bounds!"
        );

        Proposal storage proposal = s_proposals[_proposalId];

        require(block.timestamp < proposal.deadline, "Proposal expired!");

        require(
            !s_hasVoted[_proposalId][msg.sender],
            "You have already voted. You cant vote more than one time!"
        );

        uint256 voterBalance = i_token.getPastVotes(
            msg.sender,
            proposal.snapshotBlock
        );
        require(voterBalance > 0, "Yo dont have tokens to vote");

        _addVotesToProposal(_proposalId, voterBalance, _support);

        s_hasVoted[_proposalId][msg.sender] = true;
        emit Voted(_proposalId, msg.sender, _support);
    }

    /**
     * @dev Wrapper function that executes a proposal. It implements _beforeExecute hook to add
     * extra functionality before proposal execution.
     * @param _proposalId The id that identifies a proposal in the system.
     */
    function execute(uint256 _proposalId) external nonReentrant {
        _beforeExecute(_proposalId);
        _execute(_proposalId);
    }

    /**
     * @dev Execute proposal core function. The porposal execution consitst of executing the function target
     * stored in the proposal calldata data.
     * @param _proposalId The id that identifies a proposal in the system.
     */
    function _execute(uint256 _proposalId) private {
        require(
            _proposalId < s_proposals.length,
            "Proposal index out of bounds!"
        );

        Proposal storage proposal = s_proposals[_proposalId];

        require(
            !proposal.executed,
            "The proposal has already been executed! Can not reexecute again"
        );

        require(
            block.timestamp >= proposal.deadline,
            "The proposal voting has not finished!"
        );

        (uint256 voteYes, uint256 voteNo) = _getProposalVotes(_proposalId);
        require(voteYes > voteNo, "Proposal not aproved");

        proposal.executed = true;

        (bool success, ) = proposal.target.call(proposal.callData);
        require(success, "The target call has failed!");

        emit Executed(_proposalId);
    }

    /**
     * @dev The id that identifies a proposal in the system.
     */
    function getProposal(uint256 id) external view returns (Proposal memory) {
        return s_proposals[id];
    }

    /**
     * @dev Get the number of proposal in the system.
     */
    function totalProposals() external view returns (uint256) {
        return s_proposals.length;
    }

    //---------HOOKS---------//

    /**
     * @dev This is the hook that is placed before the creation of a new proposal in createProposal() function.
     * The hook allow us to add custom functionality before a proposal creation. Usefull to add governance
     * policies or previous conditions to the proposal creation. This function is virtual and can be overridden
     * by any child class that inherits from this GovernorBase contract.
     * @param _target the target address.
     * @param _callData the calldata data that includes the target function selector and its parameters encoded.
     */
    function _beforePropose(
        address _target,
        bytes calldata _callData
    ) internal virtual {}

    /**
     * @dev This is the hook that is placed before a proposal execution in the execute() function.
     * The hook allow us to add custom functionality before a proposal execution. Usefull to add governance
     * policies or previous conditions to the proposal execution. This function is virtual and can be overridden
     * by any child that inherits from this GovernorBase contract.
     * @param _proposalId The id that identifies a proposal in the system.
     */
    function _beforeExecute(uint256 _proposalId) internal virtual {}

    //----------GETTERS---------
    function getVoteInfo(
        uint256 _proposalId
    ) public view returns (uint256, uint256, uint256) {
        (
            uint256 voteYes,
            uint256 voteNo,
            uint256 totalSupply
        ) = _getProposalVoteInfo(_proposalId);
        return (voteYes, voteNo, totalSupply);
    }

    function getHasVoted(uint256 _proposalId) public view returns (bool) {
        return s_hasVoted[_proposalId][msg.sender];
    }
}
