// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Box is Ownable {
    uint256 private s_number;

    event NumberChanged(uint256 number);

    constructor() {}

    function store(uint256 number) external onlyOwner {
        s_number = number;
        emit NumberChanged(number);
    }

    function getNumber() public view returns (uint256 number) {
        return s_number;
    }
}
