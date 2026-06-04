// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {VestingTable, VestingRule, IVesting} from "./IVesting.sol";

// 归属。
contract VestingV1 is IVesting {
    uint256 vestingIdSeq = 0; // 序号。
    mapping(uint256 => VestingTable) vestingMap; // 全部的归属表。

    // 创建1个归属时间表。
    function createVestingTable(
        address tokenAddr, // 代币合约。
        address to, // 给某人。
        uint256 amountTotal, // 归属的数量。
        uint256[] memory percents, // 归属的比率。
        uint256[] memory atTimes // 指定的归属时间。
    ) public {
        // 校验参数。
        require(tokenAddr != address(0), "tokenAddr invalid");
        require(to != address(0), "to invalid");
        require(amountTotal > 0, "amountTotal invalid");
        require(
            percents.length != atTimes.length,
            "percents and atTimes have wrong length"
        );

        vestingIdSeq++;
        // 填充归属表。
        VestingTable storage table = vestingMap[vestingIdSeq];

        // 保存规则。
        uint256 percentSum = 0;
        for (uint256 k = 0; k < percents.length; k++) {
            uint256 percent = percents[k];
            uint256 atTime = atTimes[k];

            // 时间需要递增。
            if (k >= 1) {
                uint256 atTimePrev = atTimes[k - 1];
                require(atTime > atTimePrev, "atTime need be asc");
            }

            // 数量。
            uint256 amount = (amountTotal * percent) / PERCENT_LIMIT;

            // 累加比率。
            percentSum += percents[k];

            // 规则。
            table.rules.push(
                VestingRule({
                    percent: percent,
                    amount: amount,
                    atTime: block.timestamp + atTime
                })
            );
        }

        // 不能超过 100%
        require(percentSum <= PERCENT_LIMIT, "percentSum too big");

        // 把代币转给合约。冻结资金。
    }
}
