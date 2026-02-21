// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {GovernorBase} from "src/v2/GovernorBase.sol";

/**
 * @title QuorumManager
 * @dev Quorum manager policy. This allows the governor to have a quorum policy so that, before executing
 * each proposal they can check if the quorum is meet. It adds an additional condition before a proposal
 * execution. It must be inherited from a child contract to deploy it.
 */
abstract contract QuorumManager is GovernorBase {
    /// @dev the quorum that needs to be meet to pass a proposal. It is measured in basis points
    /// 10_000 basis points represents a 100%, so 1000 basis points is 10%.
    uint256 private constant QUORUM_BP = 1000; //10%

    /**
     * @dev This function calculates and check if a proposal meets the quorum or not. If the quorum is not meeted, then
     * the transaction will revert
     * @param _proposalId the proposal id that identifies the proposal in the system.
     */
    function _checkQuorum(uint256 _proposalId) private view {
        (
            uint256 voteYes,
            uint256 voteNo,
            uint256 proposalCreationTokenSupply
        ) = _getProposalVoteInfo(_proposalId);

        require(
            voteYes + voteNo >=
                (proposalCreationTokenSupply * QUORUM_BP) / 10_000,
            "Quorum not reached"
        );
    }

    /**
     * @inheritdoc GovernorBase
     * @dev this is the overrided hook placed in its GovernorBase parent. In this override we add
     * the _checkQuorum function so we can check if a proposal meets the quorum before its execution
     * in the GovernorBase.
     * @param _proposalId the proposal id that identifies the proposal in the system.
     */
    function _beforeExecute(uint256 _proposalId) internal virtual override {
        _checkQuorum(_proposalId);
        super._beforeExecute(_proposalId);
    }
}
