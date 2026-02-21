// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
 * @title VoteManager
 * @dev This abstract contract stores and keeps track all proposals votes. Usefull to inherit and add
 * vote counting functionality in our governor. Its also useful because we can access to the proposal votes
 * in other parts of our aplication.
 */
abstract contract VoteManager {
    /// @dev The votes struct data. It represents the amount of votes a proposal has.
    struct Votes {
        uint256 voteYes;
        uint256 voteNo;
        uint256 proposalInitialTokenSupply;
    }

    /// @dev It stores the amount of votes a proposal has. All proposal votes info are indexed by their proposal id.
    mapping(uint256 => Votes) private s_proposalVotes;

    /**
     * @dev It stores a new proposal votes info. We set votesYes and voteNo to 0 (thats also by default), but
     * we also need to store the token supply amount at the time the proposal is created. This is very usefull
     * because we can use this information to calculate quorums.
     * @param _proposalId the proposal id that identifies the proposal in the system.
     * @param _creationVoteSupply the token supply amount at the proposal creation time.
     */
    function _initializeNewProposalVotes(
        uint256 _proposalId,
        uint256 _creationVoteSupply
    ) internal {
        s_proposalVotes[_proposalId] = Votes({
            voteYes: 0,
            voteNo: 0,
            proposalInitialTokenSupply: _creationVoteSupply
        });
    }

    /**
     * @dev This function adds votes to the specidfied proposal id.
     * @param _proposalId the proposal id that identifies the proposal in the system.
     * @param _votePower the vote power the user is using to vote for or against.
     * @param _support is the parameter that indicates if the voter is agains or for.
     */
    function _addVotesToProposal(
        uint256 _proposalId,
        uint256 _votePower,
        bool _support
    ) internal {
        Votes storage proposalVotes = s_proposalVotes[_proposalId];

        if (_support) {
            proposalVotes.voteYes += _votePower;
        } else {
            proposalVotes.voteNo += _votePower;
        }
    }

    /**
     * @dev This function returns the number of votes for and against.
     * @param _proposalId the proposal id that identifies the proposal in the system.
     * @return voteYes number of votes for.
     * @return voteNo number of votes against.
     */
    function _getProposalVotes(
        uint256 _proposalId
    ) internal view returns (uint256, uint256) {
        Votes storage proposalVotes = s_proposalVotes[_proposalId];

        return (proposalVotes.voteYes, proposalVotes.voteNo);
    }

    /**
     * @dev Similar to _getProposalVotes function but this one returns all the proposal vote data, included
     * the token supply when the proposal was created.
     * @param _proposalId the proposal id that identifies the proposal in the system.
     * @return voteYes number of votes for.
     * @return voteNo number of votes against.
     * @return proposalInitialTokenSupply token supply at the proposal creation time.
     */
    function _getProposalVoteInfo(
        uint256 _proposalId
    ) internal view returns (uint256, uint256, uint256) {
        Votes storage proposalVotes = s_proposalVotes[_proposalId];

        return (
            proposalVotes.voteYes,
            proposalVotes.voteNo,
            proposalVotes.proposalInitialTokenSupply
        );
    }
}
