// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract GovernedContract {
    address public dao;
    uint256 public counter = 0;

    constructor(address _dao) {
        dao = _dao;
    }

    modifier onlyDAO() {
        require(msg.sender == dao, "Only DAO can call this function");
        _;
    }

    function increaseCounter(uint256 amount) public onlyDAO {
        counter += amount;
    }

    function decreaseCounter(uint256 amount) public onlyDAO {
        if (amount <= counter) {
            counter -= amount;
        } else {
            counter = 0;
        }
    }
}
