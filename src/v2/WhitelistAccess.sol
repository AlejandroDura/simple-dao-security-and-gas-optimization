// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {GovernorBase} from "src/v2/GovernorBase.sol";

/**
 * @title WhitelistAccess
 * @dev Whitelist policy to allow only whitelisted targets. This policy allows the governor to
 * execute functions in the allowed targets. A target is allowed if it is inside the whitelist.
 */
abstract contract WhitelistAccess is GovernorBase {
    /// @dev The whitelist. It is where we store the targets the governor is allowed to call or interact.
    mapping(address => bool) private s_allowedTargets;

    /// @dev This is where we store the allowed selectors (functions) asociated with a target that can be called.
    /// It is only used for the governor to call only a couple of its own functions.
    mapping(address => mapping(bytes4 => bool)) private s_allowedSelectors;

    /// @dev This is where we initialize s_allowedSelectors with fixed values. We allow the governor (this) to
    /// call by itself its allowTarget and disallowTarget functions. By doing this, the users can allow or ban
    /// certain targets. At the beginning of the DAO there is not allowed target to interact. Then the users are
    /// allowed to make proposals to add the targets they want to be involved in the governance. That is because
    /// we need to allow the own governor (this) to call these two functions to allow the users to add new target to interact with.
    constructor() {
        bytes4 allowTargetSelector = bytes4(
            keccak256(bytes("allowTarget(address)"))
        );
        bytes4 disallowTargetSelector = bytes4(
            keccak256(bytes("disallowTarget(address)"))
        );

        s_allowedSelectors[address(this)][allowTargetSelector] = true;
        s_allowedSelectors[address(this)][disallowTargetSelector] = true;
    }

    /**
     * @dev Allow a new target in the whitelist
     * @param _desiredTarget the address of the target we want to add in the list.
     */
    function allowTarget(address _desiredTarget) external {
        require(msg.sender == address(this), "Only dao can call this function");
        require(_desiredTarget != address(0), "Can't add zero as target");
        require(_desiredTarget != address(this), "Can't add DAO as target");

        s_allowedTargets[_desiredTarget] = true;
    }

    /**
     * @dev Disallow a target in the whitelist. This bans a target within the list.
     * @param _desiredTarget the address of the target we want to disallow.
     */
    function disallowTarget(address _desiredTarget) external {
        require(msg.sender == address(this), "Only dao can call this function");
        require(
            s_allowedTargets[_desiredTarget],
            "Target does not exist or is banned"
        );

        s_allowedTargets[_desiredTarget] = false;
    }

    /**
     * @dev This function checks if a target is whitelisted. If not the transaction will revert. In case the
     * target is the governor (this), then we check wether the encoded selector in the callData parameter is allowed.
     * We only check selectors for the governor DAO, because we don't want that a proposal executes any governor function.
     * We need to allow only those selectors specified in the constructor. In other targets, we don't have control about their
     * functions because we can't predict what target the governance is going to whitelist. The selector checks only works
     * to protect the governor DAO from malicious executions and allow only the specified functions in the WhitelistAccess
     * constructor.
     */
    function _checkAccess(
        address _target,
        bytes calldata _callData
    ) private view {
        require(_callData.length >= 4, "callData too short");

        if (_target == address(this)) {
            bytes4 selector = bytes4(_callData[:4]);
            require(
                s_allowedSelectors[_target][selector],
                "Not allowed selector"
            );
        } else {
            require(s_allowedTargets[_target], "Target not whitelisted");
        }
    }

    /**
     * @inheritdoc GovernorBase
     * @dev This is the overrided hook from the GovernorBase parent. In this override we add the _checkAccess()
     * function. This will allow the DAO to check if the proposal target is allowed before the propose.
     */
    function _beforePropose(
        address _target,
        bytes calldata _callData
    ) internal virtual override {
        _checkAccess(_target, _callData);
        super._beforePropose(_target, _callData);
    }

    //-------GETTERS------//
    function getTargetAllowed(address _target) public view returns (bool) {
        return s_allowedTargets[_target];
    }

    function getAllowedSelector(
        address _target,
        bytes4 _selector
    ) public view returns (bool) {
        return s_allowedSelectors[_target][_selector];
    }
}
