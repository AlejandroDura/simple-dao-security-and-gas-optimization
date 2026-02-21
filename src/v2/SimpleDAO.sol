// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {GovernorBase} from "src/v2/GovernorBase.sol";
import {WhitelistAccess} from "src/v2/WhitelistAccess.sol";
import {QuorumManager} from "src/v2/QuorumManager.sol";

/**
 * @title SimpleDAO
 * @dev This is the final governor DAO contract. This contract contains all the governance logic inherited
 * from its parents. First, we have GovernorBase where all the governance core logic is placed, and then
 * the governance policies: a whitelist placed in WhitelistAccess contract and quorum placed in QuorumManager contract:
 * The WhitelistAccess consist of a whitelist to allow or ban proposal targets.
 * The QuorumManager checks wheter a proposal can be executed based on the quorum.
 */
contract SimpleDAO is GovernorBase, WhitelistAccess, QuorumManager {
    constructor(address _token) GovernorBase(_token) {}

    /**
     * @inheritdoc GovernorBase
     * @dev This is a hook overrided from GovernorBase. This hook is used to add additional logic before
     * a proposal propose. In this case we are overriding the _beforeProposal hook of WhitelistAccess which
     * contains the whitelist logic needed. The WhitelistAccess also overrides this hook from GovernorBase.
     * Before proposing a proposal, the whitelist logic is applied to check whether a proposal target is allowed.
     */
    function _beforePropose(
        address _target,
        bytes calldata _callData
    ) internal override(GovernorBase, WhitelistAccess) {
        super._beforePropose(_target, _callData);
    }

    /**
     * @inheritdoc GovernorBase
     * @dev This is the hook overrided from GovernorBase. This hook is used to add additional logic before
     * a proposal execution. In this case we are overriding the _beforeExecute hook of QuorumManager which
     * contains the quorum logic needed. The QuorumManager also overrides this hook from GovernorBase.
     * Before executing a proposal, the quorum logic is applied to check wheter a proposal meets the quorum.
     */
    function _beforeExecute(
        uint256 _proposalId
    ) internal override(GovernorBase, QuorumManager) {
        super._beforeExecute(_proposalId);
    }
}
