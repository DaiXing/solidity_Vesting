// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

// 百分比系数。
uint256 constant PERCENT_LIMIT = 10000;

// 归属时间表。
struct VestingTable {
    // 代币合约。
    address tokenAddr;
    // 给某人。
    address to;
    // 归属的数量。
    uint256 amountTotal;
    // 已经发放的数量。
    uint256 amountGiven;
    // 规则。
    VestingRule[] rules;
}
// 归属的规则。
struct VestingRule {
    // 归属的比率。
    uint256 percent;
    // 归属的数量。
    uint256 amount;
    // 到达指定的时间。
    uint256 atTime;
}
// 归属接口。
interface IVesting {
    event OK();
}
