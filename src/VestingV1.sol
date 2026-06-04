// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {VestingTable, VestingRule, IVesting} from "./IVesting.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// 百分比系数。
uint256 constant PERCENT_LIMIT = 10000;

// 归属。
contract VestingV1 is IVesting {
    uint256 vestingIdSeq = 0; // 序号。
    mapping(uint256 => VestingTable) vestingMap; // 全部的归属表。

    modifier needOwner(uint256 vestingId) {
        needOwner_(vestingId);
        _;
    }
    function needOwner_(uint256 vestingId) private view {
        VestingTable storage table = vestingMap[vestingId];
        require(table.to == msg.sender, "not vesting owner");
    }

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
        require(percents.length > 0, "percents empty");
        require(
            percents.length != atTimes.length,
            "percents and atTimes have wrong length"
        );

        // 校验token数量。
        IERC20 erc20 = IERC20(tokenAddr);
        uint256 balance = erc20.balanceOf(msg.sender);
        require(amountTotal <= balance, "token balance not enougth");

        vestingIdSeq++;
        // 填充归属表。
        VestingTable storage table = vestingMap[vestingIdSeq];

        // 需要归属表的数量
        uint256 amountForVestingTable = 0;

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
            amountForVestingTable += amount;

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

        // 除法，可能除不尽。
        uint256 amountLeft = amountTotal - amountForVestingTable;
        if (amountLeft > 0) {
            // 100% 。就加到最后一个rule。
            if (percentSum == PERCENT_LIMIT) {
                table.rules[table.rules.length - 1].amount += amountLeft;
            }
            // 立即发送给用户。
            else {
                erc20.transferFrom(msg.sender, to, amountLeft);
            }
        }

        // 把代币转给合约。冻结资金。
        uint256 amountForContract = (percentSum == PERCENT_LIMIT)
            ? amountTotal
            : amountForVestingTable;
        erc20.transferFrom(msg.sender, address(this), amountForContract);
    }

    // 更新我的归属。
    function updateMyVesting(uint256 vestingId) private {
        VestingTable storage table = vestingMap[vestingId];

        // 遍历规则。
        uint256 ruleLen = table.rules.length;
        for (uint256 k = table.ruleScanIndex; k < ruleLen; k++) {
            VestingRule storage rule = table.rules[k];
            // 已经归属了。忽略。
            if (rule.vested) {
                continue;
            }
            // 未到时间。忽略。 后面的都不用看了。
            if (block.timestamp < rule.atTime) {
                break;
            }
            // 已到时间。执行归属。
            table.amountVested += rule.amount;
            rule.vested = true;
            table.ruleScanIndex = k;
        }
    }
}
