// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {
    VestingParam,
    VestingType,
    IVesting2,
    VestingSched
} from "./IVesting2.sol";
import {
    UUPSUpgradeable
} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

// 归属。
contract VestingV2 is IVesting2, UUPSUpgradeable, AccessControl {
    uint256 vestingIdSeq = 0; // 序号。
    mapping(uint256 => VestingSched) vestingMap; // 全部的归属表。 key= vestingId
    mapping(address => VestingSched[]) userVestingMap; // 用户的归属列表。 key= 用户addr

    // 百分比系数。
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // 初始化。
    function initialize() public {
        vestingIdSeq = 0;

        // 权限。
        grantRole(ADMIN_ROLE, msg.sender);
    }

    // 升级。
    function _authorizeUpgrade(
        address impl
    ) internal override onlyRole(ADMIN_ROLE) {}

    modifier needOwner(uint256 vestingId) {
        needOwner_(vestingId);
        _;
    }
    function needOwner_(uint256 vestingId) private view {
        // 管理员。权限大。
        // if (hasRole(ADMIN_ROLE, msg.sender)) {
        //     return;
        // }
        VestingSched storage table = vestingMap[vestingId];
        require(table.to == msg.sender, "vesting not owner");
        require(table.amount > 0, "vesting not found");
    }

    // 创建1个归属。
    function createVesting(
        address tokenAddr, // 代币合约。
        address to, // 给某人。
        VestingParam memory param // 参数。
    ) public {
        // 校验参数。
        require(tokenAddr != address(0), "tokenAddr invalid");
        require(to != address(0), "to invalid");
        require(param.amount > 0, "amount invalid");
        require(param.timeBegin >= block.timestamp, "timeBegin invalid");
        require(param.timeDuration > 100, "timeDuration invalid");

        // 校验token数量。
        IERC20 erc20 = IERC20(tokenAddr);
        uint256 balance = erc20.balanceOf(msg.sender);
        require(param.amount <= balance, "token balance not enougth");

        vestingIdSeq++;

        // 填充归属表。
        VestingSched storage table = vestingMap[vestingIdSeq];
        table.vestingType = param.vestingType;
        table.amount = param.amount;
        table.timeBegin = param.timeBegin;
        table.timeDuration = param.timeDuration;
        table.vestingId = vestingIdSeq;
        table.tokenAddr = tokenAddr;
        table.to = to;
        userVestingMap[msg.sender].push(table);

        // 冻结token。
        erc20.transferFrom(msg.sender, address(this), param.amount);
    }

    // 更新我的归属。
    function updateMyVesting() private {
        VestingSched[] storage scheds = userVestingMap[msg.sender];
        if (scheds.length == 0) {
            return;
        }
        // 遍历。
        uint256 len = scheds.length;
        for (uint256 k = 0; k < len; k++) {
            VestingSched storage sched = scheds[k];
            // 没有到开始时间。
            if (block.timestamp < sched.timeBegin) {
                continue;
            }
            // 已经过了结束时间。全部归属。
            uint256 timeEnd = sched.timeBegin + sched.timeDuration;
            if (block.timestamp >= timeEnd) {
                sched.amountVested = sched.amount;
            }
            // 分情况。
            // 悬崖模式。只看开始时间。
            if (VestingType.CLIFF == sched.vestingType) {
                continue;
            }
            // 线性模式。算时间比例。
            if (VestingType.LINEAR == sched.vestingType) {
                // 过了多久。
                uint256 offSeconds = block.timestamp - sched.timeBegin;
                // 百分比。
                sched.amountVested =
                    (sched.amount * offSeconds) /
                    sched.timeDuration;
                continue;
            }
        }
    }

    // 查询信息。
    function queryVesting(
        uint256 vestingId
    )
        public
        needOwner(vestingId)
        returns (
            address tokenAddr,
            uint256 amount,
            uint256 amountVested,
            uint256 amountClaimed
        )
    {
        updateMyVesting();

        VestingSched storage table = vestingMap[vestingId];

        return (
            table.tokenAddr,
            table.amount,
            table.amountVested,
            table.amountClaimed
        );
    }

    // 领取。 看单个归属。
    function claimSingle(
        uint256 vestingId
    ) public needOwner(vestingId) returns (uint256) {
        updateMyVesting();

        VestingSched storage table = vestingMap[vestingId];

        // 可领取金额。
        uint256 amountPending = table.amountVested - table.amountClaimed;

        if (amountPending > 0) {
            table.amountClaimed += amountPending;

            // 转token
            IERC20 erc20 = IERC20(table.tokenAddr);
            bool ok = erc20.transfer(table.to, amountPending);
            require(ok, "token transfer fail");
        }

        return (amountPending);
    }

    // 领取。 看全部归属。
    function claimAll() public returns (uint256) {
        VestingSched[] storage scheds = userVestingMap[msg.sender];
        if (scheds.length == 0) {
            return 0;
        }
        uint256 sum = 0;
        // 遍历。
        uint256 len = scheds.length;
        for (uint256 k = 0; k < len; k++) {
            VestingSched storage sched = scheds[k];
            sum += claimSingle(sched.vestingId);
        }
        return sum;
    }
}
