# Olend DeFi 借贷平台需求文档

## 介绍

Olend 是一个基于 Sui Network 的去中心化借贷平台，使用 Sui Move 作为智能合约语言。该平台的核心特点是统一流动性管理和高效的清算机制，旨在为用户提供高资本效率的借贷服务。

平台采用模块化架构，包含流动性管理、借贷、预言机、账户管理和清算等核心模块，支持多种资产的存款、借贷和清算操作。

## 需求

### 需求 1: 统一流动性管理系统

**用户故事:** 作为平台运营者，我希望建立一个统一的流动性管理系统，以便最大化资本效率并简化资产管理。

#### 验收标准

1. WHEN 平台部署时 THEN 系统 SHALL 创建一个 AdminCap 对象并分配给部署者
2. WHEN 平台初始化时 THEN 系统 SHALL 创建一个全局 Registry 对象来管理所有资产金库
3. WHEN 平台部署时 THEN 系统 SHALL 默认创建 SUI 资产的金库 Vault<SUI>
4. WHEN liquidity module 提供 create_vault 功能时 THEN 系统 SHALL 要求 AdminCap 引用作为输入参数
5. WHEN 新资产类型添加时 AND 提供有效 AdminCap 引用时 THEN 系统 SHALL 为该资产创建唯一的 Vault<T> 对象
6. WHEN 资产操作发生时 THEN 系统 SHALL 通过 Vault 的四个核心函数（deposit, borrow, repay, withdraw）进行处理
7. WHEN 管理员暂停 Vault 时 AND 提供有效 AdminCap 引用时 THEN Vault SHALL 进入暂停状态，禁止所有用户操作
8. WHEN 管理员恢复 Vault 时 AND 提供有效 AdminCap 引用时 THEN Vault SHALL 恢复正常操作
9. WHEN 设置每日限额时 AND 提供有效 AdminCap 引用时 THEN Vault SHALL 更新每日取出限额配置
10. WHEN 调整每日限额时 AND 提供有效 AdminCap 引用时 THEN 系统 SHALL 允许动态修改限额参数
11. WHEN 每日限额生效时 THEN Vault SHALL 限制每日取出金额，达到限制后当天禁止提取
12. WHEN 新的一天开始时 THEN 系统 SHALL 自动重置每日提取限额计数器
13. WHEN AdminCap 创建时 THEN 系统 SHALL 确保其为 Owned 对象且不可复制但可转让
14. WHEN Vault 实现 ERC-4626 标准时 THEN 系统 SHALL 确保与其他 DeFi 协议的兼容性
15. WHEN 紧急情况发生时 AND 提供有效 AdminCap 引用时 THEN 系统 SHALL 支持全局暂停所有 Vault 操作
16. WHEN AdminCap 需要转移时 THEN 系统 SHALL 支持安全的权限转移机制，包括多签验证
17. WHEN 管理操作执行时 THEN 系统 SHALL 记录所有管理操作的事件日志，包括操作者、时间和参数
18. WHEN 重要参数修改时 AND 提供有效 AdminCap 引用时 THEN 系统 SHALL 实施时间锁机制，延迟生效以保证安全
19. WHEN 设置参数边界时 THEN 系统 SHALL 对每日限额等关键参数进行合理的上下限检查
20. WHEN 暂停状态下时 AND 提供有效 AdminCap 引用时 THEN 系统 SHALL 支持紧急提取机制以应对极端情况
21. WHEN 调整平台费率时 AND 提供有效 AdminCap 引用时 THEN 系统 SHALL 允许动态修改平台收费参数
22. WHEN 添加新资产时 AND 提供有效 AdminCap 引用时 THEN 系统 SHALL 通过资产白名单机制进行审核
23. WHEN 合约升级时 AND 提供有效 AdminCap 引用时 THEN 系统 SHALL 支持安全的合约升级流程和权限验证

### 需求 2: 存款借贷核心功能

**用户故事:** 作为存款用户，我希望能够存入资产获得收益，并能随时赎回我的资产。

#### 验收标准

1. WHEN 用户向 LendingPool 存入资产时 THEN 系统 SHALL 铸造相应的 YToken<T> 份额凭证并转给用户
2. WHEN 用户取款时 THEN LendingPool SHALL 解析并销毁用户提供的 YToken<T>，根据份额计算应得资产数量
3. WHEN YToken<T> 铸造时 THEN 系统 SHALL 根据当前汇率计算应铸造的份额数量
4. WHEN YToken<T> 销毁时 THEN 系统 SHALL 根据当前汇率计算用户可赎回的资产数量
5. WHEN 资产操作发生时 THEN 系统 SHALL 按时间线性计算并更新复利利息
6. WHEN 利息计算时 THEN 系统 SHALL 实时更新 YToken<T> 与底层资产的汇率
7. WHEN 用户尝试取款时 AND YToken 处于抵押状态时 THEN 系统 SHALL 验证取出后抵押率不会处于危险状态
8. WHEN 创建 LendingPool 时 THEN 系统 SHALL 支持同一资产类型的多个借贷池
9. WHEN 用户存款时 AND 存款金额低于最小限额时 THEN 系统 SHALL 拒绝该操作
10. WHEN 用户取款时 AND 取款金额低于最小限额时 THEN 系统 SHALL 拒绝该操作
11. WHEN LendingPool 达到存款上限时 THEN 系统 SHALL 暂停新的存款操作
12. WHEN 用户进行大额取款时 AND 超过即时提取限额时 THEN 系统 SHALL 实施时间延迟机制
13. WHEN 异常情况发生时 THEN 系统 SHALL 启动保护机制，暂停相关操作
14. WHEN 计算利息分配时 THEN 系统 SHALL 按照预设比例分配给存款人、开发团队和风险基金
15. WHEN YToken<T> 份额价值更新时 THEN 系统 SHALL 确保价值只能增加，不能减少（除非发生损失事件）

### 需求 3: 借款和抵押管理

**用户故事:** 作为借款用户，我希望能够提供抵押物借出不同资产，并灵活管理我的借款头寸。

#### 验收标准

1. WHEN 创建 BorrowingPool<T> 时 THEN 系统 SHALL 确保该池只支持单一类型 T 的抵押物
2. WHEN 用户提供抵押物时 THEN 系统 SHALL 通过预言机计价确定可借金额
3. WHEN 用户借款时 THEN 系统 SHALL 确保借款金额不超过最大抵押率限制
4. WHEN 创建借款头寸时 THEN 系统 SHALL 创建或更新用户的 Position 对象
5. WHEN 创建 BorrowingPool 时 THEN 系统 SHALL 支持动态利率和固定利率两种计息方式
6. WHEN 设置动态利率时 THEN 系统 SHALL 根据资金利用率动态调整借款利率
7. WHEN 设置固定利率时 AND 有用户借款后 THEN 系统 SHALL 禁止修改该利率
8. WHEN 创建借款周期时 THEN 系统 SHALL 支持不定期和定期两种模式
9. WHEN 用户还款时 THEN 系统 SHALL 先计算应付利息，支持部分还款，并更新头寸状态
10. WHEN 部分还款时 THEN 系统 SHALL 重新计算剩余借款的利息起始点
11. WHEN 头寸完全还清时 THEN 系统 SHALL 释放抵押物并关闭头寸
12. WHEN 设置抵押率时 THEN 系统 SHALL 根据资产波动性设置不同的最高抵押率（如 BTC 可达 90%以上）
13. WHEN 管理头寸时 THEN BorrowingPool SHALL 按抵押率组织头寸以便批量清算
14. WHEN 用户借款时 AND 借款金额低于最小限额时 THEN 系统 SHALL 拒绝该操作
15. WHEN 用户借款时 AND 超过个人借款限额时 THEN 系统 SHALL 拒绝该操作
16. WHEN 抵押物价值发生变化时 THEN 系统 SHALL 实时更新头寸的健康度
17. WHEN 头寸健康度低于安全阈值时 THEN 系统 SHALL 触发预警机制
18. WHEN 头寸达到清算阈值时 THEN 系统 SHALL 标记该头寸为可清算状态
19. WHEN 借款产生费用时 THEN 系统 SHALL 按照预设比例收取借款手续费
20. WHEN 定期借款到期时 THEN 系统 SHALL 自动触发还款或清算流程
21. WHEN 借款逾期时 THEN 系统 SHALL 计算并收取逾期费用

### 需求 4: 预言机价格服务

**用户故事:** 作为系统，我需要准确的价格数据来计算抵押率和触发清算。

#### 验收标准

1. WHEN 系统需要价格数据时 THEN 系统 SHALL 通过 Pyth Network 获取实时价格
2. WHEN 价格数据获取时 THEN 系统 SHALL 验证价格数据的有效性和置信度
3. WHEN 价格数据过期时 THEN 系统 SHALL 拒绝使用过期价格进行关键操作
4. WHEN 价格偏差超过阈值时 THEN 系统 SHALL 触发价格异常处理机制
5. WHEN 价格异常时 THEN 系统 SHALL 暂停相关操作并等待价格恢复正常
6. WHEN 多个价格源可用时 THEN 系统 SHALL 使用加权平均或中位数方法确定最终价格
7. WHEN 价格更新时 THEN 系统 SHALL 记录价格变化事件用于审计和分析
8. WHEN 价格聚合时 THEN 系统 SHALL 实施时间加权平均价格（TWAP）机制以防止价格操纵
9. WHEN 预言机网络拥堵时 THEN 系统 SHALL 实施价格缓存和延迟更新策略
10. WHEN 检测到预言机攻击时 THEN 系统 SHALL 自动切换到备用价格源或安全模式
11. WHEN 价格波动剧烈时 THEN 系统 SHALL 增加价格更新频率并调整风险参数
12. WHEN 新资产添加时 THEN 系统 SHALL 验证预言机数据源的可靠性和历史表现
13. WHEN 价格数据不一致时 THEN 系统 SHALL 使用多数共识机制确定最终价格
14. WHEN 预言机维护时 THEN 系统 SHALL 提前通知并启用备用数据源

### 需求 5: 用户账户管理

**用户故事:** 作为用户，我希望有一个统一的账户系统来管理我的所有头寸和账户信息。

#### 验收标准

1. WHEN 平台初始化时 THEN 系统 SHALL 创建 AccountRegistry 来管理所有用户账户
2. WHEN 用户首次使用时 THEN 系统 SHALL 为用户创建 Account 对象记录详情
3. WHEN 用户操作时 THEN 系统 SHALL 通过 AccountCap 验证用户权限
4. WHEN AccountCap 创建时 THEN 系统 SHALL 确保其不可转让性
5. WHEN Account 创建时 THEN 系统 SHALL 初始化用户等级和积分为默认值
6. WHEN 用户进行平台操作时 THEN 系统 SHALL 根据操作类型和金额更新用户积分
7. WHEN 用户积分达到升级阈值时 THEN 系统 SHALL 自动提升用户等级
8. WHEN 用户等级提升时 THEN 系统 SHALL 解锁相应的特权和优惠
9. WHEN 查询用户信息时 THEN 系统 SHALL 返回用户的所有头寸、等级和积分信息
10. WHEN 跨模块操作时 THEN 系统 SHALL 确保用户数据的一致性和完整性
11. WHEN 并发操作发生时 THEN 系统 SHALL 实施乐观锁机制防止数据竞争
12. WHEN 批量操作执行时 THEN 系统 SHALL 保证操作的原子性，要么全部成功要么全部失败
13. WHEN 用户等级为VIP时 THEN 系统 SHALL 提供更低的手续费率和更高的借贷限额
14. WHEN 用户为大客户时 THEN 系统 SHALL 提供专属的风险参数和优先清算保护
15. WHEN 用户提供流动性时 THEN 系统 SHALL 给予额外的积分奖励和等级加速
16. WHEN 账户异常时 THEN 系统 SHALL 自动冻结相关操作并通知用户
17. WHEN 用户长期不活跃时 THEN 系统 SHALL 实施账户休眠机制以节省资源

### 需求 6: 高效清算机制

**用户故事:** 作为任何用户，我希望能够参与清算风险头寸，获得合理的清算奖励。

#### 验收标准

1. WHEN 头寸达到清算条件时 THEN 系统 SHALL 允许任何用户执行清算操作
2. WHEN 执行清算时 THEN 系统 SHALL 支持基于 Tick 的批量清算机制
3. WHEN 批量清算时 THEN 系统 SHALL 在同一价格范围内同时清算多个风险头寸
4. WHEN 设置清算参数时 THEN 系统 SHALL 支持极低的清算罚金（低至 0.1%）
5. WHEN 清算执行时 THEN 系统 SHALL 采用阶梯式清算，每次清算 10% 或达到安全区域
6. WHEN 清算资产时 THEN 系统 SHALL 将抵押的 YToken 对应资产通过外部 DEX（如 DEEPBook, Cetus, Bluefin）进行兑换
7. WHEN 清算完成时 THEN 系统 SHALL 向清算人支付清算奖励
8. WHEN 计算清算奖励时 THEN 系统 SHALL 根据清算金额和设定的奖励比例计算
9. WHEN 清算失败时 THEN 系统 SHALL 回滚所有状态变更并返回错误信息
10. WHEN 多个清算人同时清算时 THEN 系统 SHALL 按照交易顺序处理，避免重复清算
11. WHEN 清算优先级排序时 THEN 系统 SHALL 优先清算风险最高和价值最大的头寸
12. WHEN 跨DEX清算时 THEN 系统 SHALL 选择滑点最小和流动性最好的交易路径
13. WHEN 检测到MEV攻击时 THEN 系统 SHALL 实施随机延迟和批量处理机制
14. WHEN 清算量过大时 THEN 系统 SHALL 分批执行以减少市场冲击
15. WHEN 市场极端波动时 THEN 系统 SHALL 动态调整清算参数和奖励比例
16. WHEN 清算人资金不足时 THEN 系统 SHALL 支持闪电贷清算机制
17. WHEN 清算争议时 THEN 系统 SHALL 提供清算历史和证据查询功能
18. WHEN 清算效率低下时 THEN 系统 SHALL 自动调整清算策略和参数优化

### 需求 7: 平台治理和收益分配

**用户故事:** 作为利益相关者，我希望平台有清晰的治理结构和收益分配机制。

#### 验收标准

1. WHEN 平台产生收益时 THEN 系统 SHALL 将 10% 分配给开发团队作为运营费用
2. WHEN 平台产生收益时 THEN 系统 SHALL 将 10% 分配给风险基金
3. WHEN 平台产生收益时 THEN 系统 SHALL 将剩余 80% 分配给相应的存款人
4. WHEN 平台出现风险或损失时 THEN 系统 SHALL 使用风险基金资产进行补偿
5. WHEN 风险基金不足时 THEN 系统 SHALL 触发紧急治理流程
6. WHEN 平台运营者设置参数时 THEN 系统 SHALL 允许调整平台策略和参数
7. WHEN 开发者部署维护时 THEN 系统 SHALL 支持平台的持续运营和升级
8. WHEN 收益分配时 THEN 系统 SHALL 自动执行分配逻辑，无需人工干预
9. WHEN 分配比例需要调整时 AND 提供有效 AdminCap 引用时 THEN 系统 SHALL 允许修改分配参数

### 需求 8: 安全和风险控制

**用户故事:** 作为所有用户，我希望平台具有完善的安全机制和风险控制措施。

#### 验收标准

1. WHEN 检测到异常情况时 THEN 系统 SHALL 支持紧急暂停功能
2. WHEN 设置风险参数时 THEN 系统 SHALL 根据资产特性设置合理的抵押率和清算阈值
3. WHEN 市场波动时 THEN 系统 SHALL 动态调整风险参数以保护平台安全
4. WHEN 用户操作时 THEN 系统 SHALL 验证所有操作的合法性和安全性
5. WHEN 资产管理时 THEN 系统 SHALL 确保资产的安全存储和正确计算
6. WHEN 大额操作发生时 THEN 系统 SHALL 实施额外的安全检查和确认机制
7. WHEN 检测到可疑活动时 THEN 系统 SHALL 自动触发风险预警和保护措施
8. WHEN 系统升级时 THEN 系统 SHALL 确保升级过程的安全性和数据完整性
9. WHEN 外部依赖失效时 THEN 系统 SHALL 启用降级模式保证核心功能可用
10. WHEN 进行风险评估时 THEN 系统 SHALL 综合考虑市场风险、技术风险和操作风险

### 需求 9: 用户体验和业务规则

**用户故事:** 作为用户，我希望平台提供透明、友好的用户体验和清晰的业务规则。

#### 验收标准

1. WHEN 用户执行操作前 THEN 系统 SHALL 显示详细的手续费预估和风险提示
2. WHEN 用户确认操作时 THEN 系统 SHALL 提供操作撤销的时间窗口（如适用）
3. WHEN 操作涉及风险时 THEN 系统 SHALL 要求用户明确确认风险警告
4. WHEN 新用户使用平台时 THEN 系统 SHALL 提供操作指导和教育材料
5. WHEN 用户等级不同时 THEN 系统 SHALL 提供差异化的手续费率和服务
6. WHEN 用户为市场制造商时 THEN 系统 SHALL 提供额外的激励和奖励
7. WHEN 用户操作失败时 THEN 系统 SHALL 提供清晰的错误信息和解决建议
8. WHEN 用户查询历史时 THEN 系统 SHALL 提供完整的操作记录和收益统计
9. WHEN 市场条件变化时 THEN 系统 SHALL 主动通知受影响的用户
10. WHEN 用户资金安全受威胁时 THEN 系统 SHALL 立即通知并提供保护措施
11. WHEN 用户进行大额操作时 THEN 系统 SHALL 提供专属客服和优先处理
12. WHEN 平台推出新功能时 THEN 系统 SHALL 为现有用户提供平滑的迁移路径
13. WHEN 用户反馈问题时 THEN 系统 SHALL 提供多渠道的客户支持和问题追踪
14. WHEN 监管要求变化时 THEN 系统 SHALL 确保合规性并及时通知用户相关变更