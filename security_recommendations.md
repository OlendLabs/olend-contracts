# 安全改进建议

## 1. AdminCap 安全增强

### 当前风险
- AdminCap 可以被直接转移，缺乏多签保护
- 没有紧急恢复机制
- 缺少权限转移的时间锁

### 建议实现
```move
public struct AdminCap has key {
    id: UID,
    // 添加多签支持
    required_signatures: u8,
    signers: vector<address>,
    // 添加时间锁
    transfer_timelock: u64,
    pending_transfer: Option<PendingTransfer>,
}

public struct PendingTransfer has store {
    new_owner: address,
    initiated_at: u64,
    signatures: vector<address>,
}
```

## 2. 全局暂停机制增强

### 当前实现
```move
public struct Registry has key {
    // ...
    paused: bool,  // 全局暂停状态未被使用
}
```

### 建议改进
- 实现全局暂停检查
- 添加紧急暂停触发条件
- 实现分级暂停机制

## 3. 时间相关安全问题

### 发现的问题
- 每日限额重置依赖系统时间，可能被操纵
- 缺少时间戳验证机制

### 建议修复
- 添加时间戳合理性检查
- 实现更安全的时间窗口机制