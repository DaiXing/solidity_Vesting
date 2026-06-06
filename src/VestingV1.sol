// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {
    VestingParam,
    VestingType,
    VestingState,
    IVesting,
    VestingSched
} from "./IVesting.sol";
import {
    UUPSUpgradeable
} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

// 归属。
contract VestingV1 is IVesting, UUPSUpgradeable, AccessControl {
    uint256 vestingIdSeq = 0; // 序号。
    mapping(uint256 => VestingSched) vestingMap; // 全部的归属表。 key= vestingId
    mapping(address => uint256[]) userVestingMap; // 用户的归属列表。 key= 用户addr value= vestingId

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
        // 管理员。可以撤销或发放。
        if (hasRole(ADMIN_ROLE, msg.sender)) {
            return;
        }
        VestingSched storage sched = vestingMap[vestingId];
        require(sched.to == msg.sender, "vesting not owner");
        require(sched.amount > 0, "vesting not found");
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
        VestingSched storage sched = vestingMap[vestingIdSeq];
        sched.vestingType = param.vestingType;
        sched.amount = param.amount;
        sched.timeBegin = param.timeBegin;
        sched.timeDuration = param.timeDuration;
        sched.vestingId = vestingIdSeq;
        sched.tokenAddr = tokenAddr;
        sched.from = msg.sender;
        sched.to = to;
        sched.state = VestingState.NORMAL;
        userVestingMap[msg.sender].push(sched.vestingId);

        // 冻结token。
        bool ok = erc20.transferFrom(msg.sender, address(this), param.amount);
        require(ok, "transferFrom fail");

        emit VestingCreated(
            sched.vestingId,
            sched.tokenAddr,
            sched.to,
            sched.amount,
            sched.timeBegin,
            sched.timeDuration
        );
    }

    // 更新我的归属。
    function updateMyVesting() private {
        uint256[] storage scheds = userVestingMap[msg.sender];
        if (scheds.length == 0) {
            return;
        }
        // 遍历。
        uint256 len = scheds.length;
        for (uint256 k = 0; k < len; k++) {
            uint256 tmpId = scheds[k];
            updateSingleVesting(tmpId);
        }
    }

    // 更新1个归属。
    function updateSingleVesting(uint256 vestingId) private {
        VestingSched storage sched = vestingMap[vestingId];
        if (sched.amount == 0) {
            return;
        }
        // 状态。
        if (sched.state != VestingState.NORMAL) {
            return;
        }
        // 没有到开始时间。
        if (block.timestamp < sched.timeBegin) {
            return;
        }
        // 已经过了结束时间。全部归属。
        uint256 timeEnd = sched.timeBegin + sched.timeDuration;
        if (block.timestamp >= timeEnd) {
            sched.amountVested = sched.amount;
        }
        // 分情况。
        // 悬崖模式。只看开始时间。
        if (VestingType.CLIFF == sched.vestingType) {
            return;
        }
        // 线性模式。算时间比例。
        if (VestingType.LINEAR == sched.vestingType) {
            // 过了多久。
            uint256 offSeconds = block.timestamp - sched.timeBegin;
            // 百分比。
            sched.amountVested =
                (sched.amount * offSeconds) /
                sched.timeDuration;
            return;
        }
    }

    // 清理我的归属。
    function cleanVesting(address user) private {
        uint256[] storage scheds = userVestingMap[user];
        if (scheds.length == 0) {
            return;
        }

        // 遍历。
        uint256 len = scheds.length;
        // 倒序。 便于删除。
        for (uint256 k = len - 1; k >= 0; k--) {
            uint256 tmpId = scheds[k];
            VestingSched storage sched = vestingMap[tmpId];
            // 都领取了，或者撤销了。可以删除。
            if (
                sched.amount == sched.amountClaimed ||
                sched.state == VestingState.REVOKED
            ) {
                delete vestingMap[tmpId];
                // 当前元素、末尾元素，互换。删除末尾。
                scheds[k] = scheds[scheds.length - 1];
                scheds.pop();

                emit VestingDeleted(sched.vestingId, sched.tokenAddr, sched.to);
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
        updateSingleVesting(vestingId);

        VestingSched storage sched = vestingMap[vestingId];

        return (
            sched.tokenAddr,
            sched.amount,
            sched.amountVested,
            sched.amountClaimed
        );
    }

    // 领取。 看单个归属。
    function claimSingle(
        uint256 vestingId
    ) public needOwner(vestingId) returns (uint256) {
        updateSingleVesting(vestingId);

        VestingSched storage sched = vestingMap[vestingId];

        // 可领取金额。
        uint256 amountPending = sched.amountVested - sched.amountClaimed;

        if (amountPending > 0) {
            // 累加。
            sched.amountClaimed += amountPending;

            // 转token
            IERC20 erc20 = IERC20(sched.tokenAddr);
            bool ok = erc20.transfer(sched.to, amountPending);
            require(ok, "token transfer fail");

            emit VestingClaimed(
                sched.vestingId,
                sched.tokenAddr,
                sched.to,
                amountPending
            );
        }

        // 都领取了。删除。
        if (sched.amount == sched.amountClaimed) {
            cleanVesting(msg.sender);
        }

        return (amountPending);
    }

    // 领取。 看全部归属。
    function claimAll() public returns (uint256) {
        // 拷贝ID。
        uint256[] memory scheds = userVestingMap[msg.sender];
        if (scheds.length == 0) {
            return 0;
        }
        uint256 sum = 0;
        // 遍历。
        uint256 len = scheds.length;
        for (uint256 k = 0; k < len; k++) {
            sum += claimSingle(scheds[k]);
        }
        return sum;
    }

    // 撤销。 已归属的，发放。其他的，回退。
    function revoke(uint256 vestingId) public onlyRole(ADMIN_ROLE) {
        // 触发领取。
        claimSingle(vestingId);

        VestingSched storage sched = vestingMap[vestingId];

        // 剩余数量，返还。
        uint256 amountLeft = sched.amount - sched.amountClaimed;
        if (amountLeft > 0) {
            // 状态。
            sched.state = VestingState.REVOKED;

            // 转token
            IERC20 erc20 = IERC20(sched.tokenAddr);
            bool ok = erc20.transfer(sched.from, amountLeft);
            require(ok, "token transfer fail");
        }

        // 清理。
        cleanVesting(sched.to);

        emit VestingRevoked(
            sched.vestingId,
            sched.tokenAddr,
            sched.to,
            amountLeft
        );
    }
}
