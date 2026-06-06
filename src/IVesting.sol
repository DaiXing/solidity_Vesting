// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

// 归属类型。
enum VestingType {
    // 悬崖模式。到了截止时间，一次性给。
    CLIFF,
    // 线性模式。按时间比例给。
    LINEAR
}
// 状态。
enum VestingState {
    // 正常状态
    NORMAL,
    // 撤销了。
    REVOKED
}
// 归属的参数。
struct VestingParam {
    // 归属类型。
    VestingType vestingType;
    // 归属的数量。
    uint256 amount;
    // 开始时间。
    uint256 timeBegin;
    // 持续时间。秒。
    uint256 timeDuration;
}
// 归属的时间表。
struct VestingSched {
    // 归属类型。
    VestingType vestingType;
    // 归属的数量。
    uint256 amount;
    // 开始时间。
    uint256 timeBegin;
    // 持续时间。秒。
    uint256 timeDuration;
    // -------------------------
    // 序号。
    uint256 vestingId;
    // 是否已经全部归属。
    bool vestedAll;
    // 状态。
    VestingState state;
    // 代币合约。
    address tokenAddr;
    // 来源。
    address from;
    // 给某人。
    address to;
    // 已经归属的数量。
    uint256 amountVested;
    // 已经发放的数量。
    uint256 amountClaimed;
}
// 归属接口。
interface IVesting {
    // 创建归属。
    event VestingCreated(
        uint256 indexed vestingId,
        address indexed tokenAddr,
        address indexed to,
        uint256 amount,
        uint256 timeBegin,
        uint256 timeDuration
    );
    // 删除归属。
    event VestingDeleted(
        uint256 indexed vestingId,
        address indexed tokenAddr,
        address indexed to
    );
    // 领取归属。
    event VestingClaimed(
        uint256 indexed vestingId,
        address indexed tokenAddr,
        address indexed to,
        uint256 amountTransfer // 转账数量。
    );
    // 撤销归属。
    event VestingRevoked(
        uint256 indexed vestingId,
        address indexed tokenAddr,
        address indexed to,
        uint256 amountReturn //返还数量。
    );
}
