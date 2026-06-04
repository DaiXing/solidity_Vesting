// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {VestingTable, VestingRule, IVesting} from "./IVesting.sol";

// 归属。
contract VestingV1 is IVesting {
    uint256 public number;

    function setNumber(uint256 newNumber) public {
        number = newNumber;
    }

    function increment() public {
        number++;
    }
}
