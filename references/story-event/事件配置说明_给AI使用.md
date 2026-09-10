# Bubble 项目事件配置说明（给策划与 AI 使用）

> 审阅日期：2026-09-01  
> 依据：当前事件 Excel 源表与 `Code/BubteaHam_trunk` 运行时代码。  
> 本文描述当前版本的实际配置和代码行为；未修改任何源 Excel。  
> 剧情、对白和文本的详细配置另见：[剧情配置说明_给AI使用.md](./剧情配置说明_给AI使用.md)。
> 日常需求统一填写到根目录的 [剧情事件需求池.xlsx](./剧情事件需求池.xlsx)，完整接单、草案、QA、激活和归档流程见 [剧情事件AI配置工作流.md](./剧情事件AI配置工作流.md)；`剧情事件AI输入模板/` 仅保留作旧版兼容资料。

## 1. 一句话理解事件系统

```text
外部触发信号
→ tEventTrigger：什么时候尝试触发、选哪个事件池标签
→ tEventPool：按等级、完成次数和规则选一个 groupId
→ tEventGroup：按业务条件和权重选出最终具体事件 id
→ 按 eventType 读取同 id 的事件详情表
→ 执行并完成事件，回传具体 tEventGroup.id
→ 可触发后续事件或 tPlot
→ tPlotStep → tDialogueTable → tDialogContent → tlanguage_cn
```

四类 ID 不能混用：

| ID | 真实用途 |
|---|---|
| `tEventTrigger.id` | 触发规则 ID；触发次数、存档和运行状态以它为键 |
| `tEventPool.id` | 池规则行 ID；触发器不直接引用它 |
| `tEventGroup.groupId` | 被池选中的分组键 |
| `tEventGroup.id` | 最终具体事件 ID；详情表、完成通知、后续事件和剧情监听都用它 |

核心等式：

```text
tEventTrigger.eventPoolId[] 元素 = tEventPool.eventType
tEventPool.eventTypeId[] 元素     = tEventGroup.groupId
tEventGroup.id                    = 对应事件详情表.id
tPlot 的事件条件参数              = tEventGroup.id
```

## 2. 事件相关工作簿

### 2.1 核心路由表

`Table/S_事件表_tEventTable.xlsx`

| Sheet | 当前有效数字 ID 行 | 作用 |
|---|---:|---|
| `tEventTrigger` | 39 行、38 个唯一 ID | 监听外部信号、限制次数、选择池标签 |
| `tEventPool` | 111 行 | 按等级和历史完成次数选择 groupId |
| `tEventGroup` | 170 行 | 筛选并选出具体事件 |
| `tTagLimit` | 8 行 | 控制同标签事件的同时活跃数量 |

### 2.2 事件详情表

| 工作簿 / Sheet | 当前有效数字 ID 行 | 对应 `tEventGroup.eventType` |
|---|---:|---|
| `S_事件_流行菜事件表_tTrendContent.xlsx / tTrendContent` | 6 | `1` 流行 |
| 同工作簿 `/ tTrendCustomerIncrease` | 3 | 流行菜数量对应客流增幅 |
| `S_事件_团餐事件表_tGroupMeal.xlsx / tGroupMeal` | 52 | `2` 团餐 |
| 同工作簿 `/ tGroupMealFood` | 40 | 可选菜品等级门槛 |
| 同工作簿 `/ tGroupMealDining` | 50 | 餐厅等级金币倍率 |
| 同工作簿 `/ tGroupMealFoodFilter` | 95 | 菜品标签、菜品和权重 |
| `S_事件_特殊顾客表_tEventCuster.xlsx / tEventCuster` | 86 行、83 个唯一 ID | `3/4/6/7` 顾客、霸王餐、商人 |
| 同工作簿 `/ tEventCusterResolut` | 98 | 顾客结果、消息、推文和对话 |
| `T_事件_天坑事件表tMineEvent.xlsx / tMineEvent` | 20 | `5` 挖矿 |
| 同工作簿 `/ tMineTalkEvent` | 23 | 挖矿事件的一项或多项交互 |
| `S_事件_通用对象交互事件_tEventGeneralProgress.xlsx` | 13 | `8` 通用对话交互 |

### 2.3 同名但独立的经营烹饪事件

`J_经营_烹饪表_tManageEventFilter.xlsx` 不走上述主链：

| Sheet | 作用 |
|---|---|
| `tManageEventFilter` | 从正常烹饪、失败等经营子事件中按条件和权重选择 |
| `tManageEventCookFail` | 按菜品火力/家具火力比值决定失败概率和失败次数 |
| `tManageEventCookTime` | 按同一比值决定烹饪时间倍率 |

不要为了配置普通事件或剧情事件，把这三张表接入 `tEventPool`。

## 3. 四张核心表怎么配

### 3.1 `tEventTrigger`：事件什么时候尝试开始

| 字段 | 当前代码中的作用 |
|---|---|
| `id` | 触发规则 ID，必须唯一 |
| `eventPoolId` | 池标签数组；元素匹配 `tEventPool.eventType`，不是 `tEventPool.id` |
| `eventPoolWeight` | 与 `eventPoolId` 按位置对齐，先按权重选一个池标签 |
| `conditionId` | 所有触发方式共用的额外门槛，引用 `tCommonCondition.id`；空/0 表示无 |
| `eventTriggerType` | 外部触发信号类型，当前代码支持 1～8 |
| `eventTriggerParam` | 与触发类型配套的参数数组 |
| `logInTrigger` | `1` 时，对尚未触发过的事件在登录时补检 |
| `eventTriggerMax` | 一个限制周期内最多成功触发次数 |
| `limitResetType` | `1` 永久；`2` 每日；`3` 每周 |
| `limitResetParam` | 每日/每周刷新时间参数 |
| `eventTag` | 引用 `tTagLimit.id`，控制同标签并发 |

当前支持的触发类型：

| 类型 | 启动信号 | `eventTriggerParam` |
|---:|---|---|
| 1 | 条件达成 | `[tCommonCondition.id]`；当前监听只用第一项 |
| 2 | 周期触发 | `[最短间隔秒,最长间隔秒]` |
| 3 | 每日在线时长且处于指定小时段 | `[最短在线秒,最长在线秒,小时下限,小时上限]` |
| 4 | 餐厅升级 | `[餐厅等级,...]` |
| 5 | 首次进入矿层/关卡 | `[关卡ID,...]` |
| 6 | 完成其他事件 | `[具体 tEventGroup.id,...]` |
| 7 | 生成任务 | `[tTask.id,...]`；不是任务完成 |
| 8 | 完成引导 | `[引导ID,...]` |

补充规则：

- `conditionId` 是真正抽事件前都会检查的门槛；`eventTriggerType=1` 是“条件达成”这个启动信号，两者不是一回事。
- `logInTrigger=1` 当前补检类型 `1、4、5、6、7、8`；类型 2/3 由自动计时更新。
- Excel 表头还有类型 9“任意食材库存低于特定量”，但当前代码没有类型 9 枚举和监听逻辑，正式实现前不要配置。
- `eventPoolId` 与 `eventPoolWeight` 长度必须相同。

### 3.2 `tTagLimit`：同时能挂多少事件

```text
tEventTrigger.eventTag → tTagLimit.id
```

| 字段 | 作用 |
|---|---|
| `eventMaxCount` | 同标签允许同时活跃的事件数量 |
| `limitHandle=1` | 满额时排队 |
| `limitHandle=2` | 满额时跳过 |

`eventMaxCount` 控制并发；`eventTriggerMax` 控制历史触发次数。

### 3.3 `tEventPool`：从哪个分组里抽

| 字段 | 当前代码中的作用 |
|---|---|
| `id` | 池行主键；触发器不直接引用 |
| `eventType` | 池标签，匹配 `tEventTrigger.eventPoolId[]`；不是事件业务类型 |
| `resLv` | 餐厅等级闭区间 `[下限,上限]` |
| `filterType` | Excel 有，但当前 `tEventPool.cs` 和运行逻辑不读取 |
| `filter` | 当前固定按该池标签的历史完成次数范围 `[最低,最高]` 判断 |
| `eventTypeId` | 候选 `tEventGroup.groupId` 数组，不是具体事件 ID |
| `randomRule=1` | 按 `eventTypeWeight` 权重随机 |
| `randomRule=2` | 顺序选择，无参数 |
| `randomRule=3` | 分布抽取，`eventTypeWeight` 为各 groupId 抽取次数 |

代码按表顺序找到第一条满足池标签、餐厅等级和完成次数的行后立即返回。因此同一 `eventType` 下的区间不要非预期重叠，否则后面的池行可能永远到不了。

### 3.4 `tEventGroup`：选出最终具体事件

| 字段 | 当前代码中的作用 |
|---|---|
| `id` | 最终具体事件 ID；必须与对应事件详情表 `id` 相同 |
| `eventType` | 决定详情表和执行模块 |
| `groupId` | 被 `tEventPool.eventTypeId[]` 引用的分组键 |
| `filter` / `filterParam` | 同一 groupId 内的候选条件 |
| `Weight` | 对通过筛选的具体事件做最终权重选择 |
| `endCondition=0` | 由事件玩法主动完成 |
| `endCondition=1` | 倒计时结束 |
| `endCondition=2` | 倒计时结束或主动放弃 |
| `endParam` | 类型 1/2 的持续秒数，当前通常读取第一项 |
| `eventEndRoleState` | 事件结束后的角色状态；空/0 时由业务决定销毁或保持 |

`filter` 类型：

| 类型 | 条件 | `filterParam` |
|---:|---|---|
| 1 | 某食材数量超过 X | `[食材ID,X]` |
| 2 | 某菜谱未解锁 | `[菜谱ID]` |
| 3 | 团餐订单拒绝次数超过 X | `[团餐 groupId,X]` |
| 4 | 团餐订单完成次数超过 X | `[团餐 groupId,X]` |
| 5 | 同时拥有全部菜谱 | `[菜谱ID,...]` |
| 6 | 某属性达到 X | `[属性ID,X]` |
| 7 | 已拥有菜谱数达到 X | `[X]` |
| 8 | 餐厅地面金币数达到 X | `[X]` |
| 9 | 已完成全部前置事件 | `[具体 tEventGroup.id,...]` |
| 10 | 已消耗某道具达到 X | `[道具ID,X]` |
| 11 | 某道具持有量低于 X | `[道具ID,X]` |
| 12 | 累计获得某道具达到 X | `[道具ID,X]` |
| 13 | 已到过某矿层/关卡 | `[关卡ID]` |
| 14 | 家具拥有数达到 X | `[X]` |

不填 `filter` 表示直接进入候选。

### 3.5 事件完成后的统一行为

事件完成会：

1. 增加具体 `tEventGroup.id` 和业务 `eventType` 的完成次数；
2. 把具体 ID 写入已完成事件集合；
3. 发出 `DurationEventEndEvent.eventGroupEventId=tEventGroup.id`；
4. 释放标签并发名额，并尝试启动排队事件。

完成通知可以：

- 被 `tEventTrigger.eventTriggerType=6` 用来启动另一个事件；
- 被 `tPlot.hangCondition=2` 用来满足剧情条件；
- 被条件、任务和业务模块用于更新目标或 UI。

三种情况的参数都用具体 `tEventGroup.id`。

## 4. `eventType` 与详情表的分发关系

| `eventType` | 含义 | 必须存在的同 ID 详情 | 主要后续关系 |
|---:|---|---|---|
| 1 | 流行 | `tTrendContent.id=tEventGroup.id` | 展示文本、流行目标、奖励 |
| 2 | 团餐 | `tGroupMeal.id=tEventGroup.id` | 菜品池、数量、奖励、订单文本 |
| 3 | 特殊顾客 | `tEventCuster.id=tEventGroup.id` | 角色、结果、消息、推文、对话 |
| 4 | 霸王餐 | `tEventCuster.id=tEventGroup.id` | 同上，具体行为由 `roleType` 决定 |
| 5 | 挖矿 | `tMineEvent.id=tEventGroup.id` | 一对多 `tMineTalkEvent.eventId` |
| 6 | 食材商人 | `tEventCuster.id=tEventGroup.id` | 商人模块继续读取角色和商人配置 |
| 7 | 家具/地毯商人 | `tEventCuster.id=tEventGroup.id` | 商人模块继续读取角色和商人配置 |
| 8 | 通用对话交互 | `tEventGeneralProgress.id=tEventGroup.id` | 直接引用 `tDialogueTable.id` |

如果具体 ID 找不到同 ID 详情，业务模块通常无法生成事件内容。

本次读回中，当前 170 条 `tEventGroup` 都能在其 `eventType` 对应详情表找到同 ID；全部 Pool 的 groupId 引用和全部 Trigger 的池标签引用也都能解析。此结论不消除后文所列的重复 ID 和表结构风险。

## 5. 各事件详情怎么配

### 5.1 类型 8：通用对象交互事件

表：`S_事件_通用对象交互事件_tEventGeneralProgress.xlsx / tEventGeneralProgress`

| 字段 | 作用 |
|---|---|
| `id` | 等于具体 `tEventGroup.id` |
| `projectType=1` | 创建角色 |
| `projectTypeParam` | `tRole.id` |
| `createWay=1` | 使用餐厅场景坐标 |
| `createWayParam` | `[x,y]` |
| `eventType=1` | 点击对象打开对话 |
| `eventTypeParam` | `[tDialogueTable.id,对话结束是否完成事件]` |
| `eventEndWay=0` | 由对话参数或事件自身决定结束 |

推荐明确写两项：

```text
eventTypeParam=[对白组ID,1]  // 对话结束后完成事件
eventTypeParam=[对白组ID,0]  // 对话结束后事件仍保持活跃
```

这里的 `eventTypeParam` 就在这张详情表，不在核心事件表。

```text
tEventGeneralProgress.eventTypeParam[0]
→ tDialogueTable.id
→ dialogueIdList[]
→ tDialogContent.id
→ roleId → tGuideTrole.id → name → tlanguage_cn.id
→ text ─────────────────────────────→ tlanguage_cn.id
```

### 5.2 类型 5：挖矿事件

表：`T_事件_天坑事件表tMineEvent.xlsx`

#### `tMineEvent`

| 字段 | 作用 |
|---|---|
| `id` | 等于具体 `tEventGroup.id` |
| `eventType=1` | NPC 通用交互事件 |
| `eventLevel` | 可出现的矿层/关卡 |
| `startType=0` | 由关卡内交互或外部因素决定 |
| `startType=1` | 进入关卡时启动 |
| `startType=2` | 进入深度区间；`startParam=[起始深度,结束深度]` |
| `startType=3` | 区间内破坏指定地块；`startParam=[起始深度,结束深度,地块ID,数量]` |
| `showBubble` | 气泡显示策略；当前代码明确处理 `1=有黑雾时隐藏` |
| `bubbletTps` | 气泡资源名数组，通常 `[揭雾前,揭雾后]` |
| `wayTps` | 方向/距离指示方式 |
| `endType=0` | 由交互本身结束 |
| `endType=2` | 满足 `endTypeParam=tCommonCondition.id` 后结束 |

#### `tMineTalkEvent`

```text
tMineTalkEvent.eventId → tMineEvent.id → tEventGroup.id
```

一个挖矿事件可以有多条交互。

| 字段 | 作用 |
|---|---|
| `id` | 单项交互唯一 ID |
| `eventId` | 所属 `tMineEvent.id` |
| `talkType=1` | 对话；`talkParam=[tDialogueTable.id,对话后是否完成事件]` |
| `talkType=2` | 数值要求；`talkParam=[属性主体,属性ID,要求值,失败提示语言ID]` |
| `talkType=3` | 队伍等级要求；`talkParam=[要求类型,等级,失败提示语言ID]` |
| `talkWay=1/2` | 点击 / 靠近；靠近时 `wayParam=[格子数]` |
| `projectType=1/2` | 创建角色 / 预制体；分别使用 `roleId` 或 `prefabPath` |
| `roleCreateWay=1` | 固定坐标；`roleCreateWayParam=[x,y]` |
| `roleCreateWay=2` | 指定地块范围；按表头格式配置地块、偏移和空腔要求 |
| `standby` / `endRoleState` | `tMineRoleState.id` |
| `endProjectRecycle` | 事件结束后的对象保留/回收策略 |
| `endClickEvent=101` | 事件结束后保留随机对话入口 |
| `endClickEventParam` | `101` 时为若干 `tDialogueTable.id` |

当前代码在对话参数缺少第二项时默认完成事件；AI 仍应显式写 `0` 或 `1`。

### 5.3 类型 3/4/6/7：特殊顾客、霸王餐和商人

表：`S_事件_特殊顾客表_tEventCuster.xlsx`

#### `tEventCuster`

| 字段 | 作用 |
|---|---|
| `id` | 等于具体 `tEventGroup.id` |
| `roleAvatar` | `tRole.id` |
| `roleType` | `1` 网红、`2` 霸王餐、`3` 小偷、`4` 食材商人、`5` 家具商人、`6` 地毯商人 |
| `roleParam` | 随角色类型解释，如霸王餐菜数范围、小偷行为参数 |
| `eventResolut` | `tEventCusterResolut.id` 数组；多项时当前逻辑第 1 项为达标，第 2 项为不达标/其他 |
| `rewardContent` | `tCommonDrop.id` 数组 |
| `refreshRule` | `0` 无限制；`1` 终生；`2` 每日；`3` 每周；`4` 完成 X 次后需重新满足条件 |
| `refreshParam` | 限制次数 X |

#### `tEventCusterResolut`

| 字段 | 作用 |
|---|---|
| `id` | 被 `eventResolut[]` 引用 |
| `resolutRewardType` | `1` 生成顾客、`2` 增属性、`3` 掉落、`4` 扣属性 |
| `resolutRewardParam` | 对应参数，例如 `[属性ID,值]`、`[掉落ID]` |
| `templateStyle` | 默认、网红达标、网红不达标、霸王餐等界面样式 |
| `consumeType` / `consumeParam` | 广告、消耗或属性达标条件 |
| `messageHeadIcon` / `messagePic` | 消息资源 |
| `messageShown` | `tlanguage_cn.id` 数组 |
| `tweet` | 严格 JSON 二维数组，如 `[[达标文本ID...],[不达标文本ID...]]`，元素都是语言 ID |
| `talk` | `tDialogueTable.id`；当前用于网红达标点击后的结果对话 |

消息和推文直接进 `tlanguage_cn`；只有 `talk` 进入对白链。

### 5.4 类型 2：团餐事件

表：`S_事件_团餐事件表_tGroupMeal.xlsx`

#### `tGroupMeal`

| 字段 | 作用 |
|---|---|
| `id` | 等于具体 `tEventGroup.id` |
| `roleAvatar` | `tRole.id` |
| `orderText` | `tlanguage_cn.id` |
| `food1ChoiceWay/food2ChoiceWay` | `0` 随机；`1` 优先已有；`2` 优先未有 |
| `food1List/food2List` | 当前代码实际匹配 `tGroupMealFoodFilter.tagId`，不是其行 `id` |
| `food1Nums/food2Nums` | 严格 JSON 二维数组 `[[数量,权重],...]` |
| `rewardContent` | `tCommonDrop.id` 数组，每个掉落 ID 各执行一次 |
| `cookTime` | 进度条表现秒数 |
| `cookAnime` | 流程动画；当前 `1` 为通用动画 |
| `refreshRule/refreshParam` | 具体事件刷新限制 |
| `thanksId` | 预留，暂不使用 |

辅助关系：

```text
tGroupMeal.food1List/food2List
→ tGroupMealFoodFilter.tagId
→ 按 weight 选 foodId
→ tGroupMealFood.id=tFood.id，检查 level≤当前餐厅等级
→ food1Nums/food2Nums 再按权重选择数量
```

| Sheet | 关键关系 |
|---|---|
| `tGroupMealFoodFilter` | `tagId` 为筛选标签；`foodId→tFood.id`；`weight` 为权重；自身 `id` 当前无业务意义 |
| `tGroupMealFood` | `id=tFood.id`；`level` 为进入候选池的最低餐厅等级 |
| `tGroupMealDining` | `id=餐厅等级`；`rewardMultiple` 计算团餐金币奖励 |

Excel 的 `requireFood` 是导出字段，但当前 `tGroupMeal.cs` 没有它；运行时需求菜品由上述动态链生成。

### 5.5 类型 1：流行菜事件

表：`S_事件_流行菜事件表_tTrendContent.xlsx`

#### `tTrendContent`

| 字段 | 作用 |
|---|---|
| `id` | 等于具体 `tEventGroup.id` |
| `eventType` | Excel 当前填写了 `3010/3020` 等值，但当前流行菜运行代码未读取；新增含义需先与程序确认 |
| `trendType=1/2/3/4` | 食材 / 菜品 / 风味分 / 口味；`trendValue` 存对应 ID 或值 |
| `effectiveFloor` | 生效楼层 |
| `trendEntrance/trendEntranceType` | 入口 Banner 资源与皮肤/图集项 |
| `posterIcon` | 海报中央图标 |
| `posterTitle/posterContent` | `tlanguage_cn.id` |
| `rewardTier` | 各档所需烹饪次数 |
| `rewardtGroup` | 与档位对齐的 `tCommonDrop.id` |

事件倒计时以 `tEventGroup.endCondition/endParam` 为准。Excel 的 `duration` 虽导出，但当前 `tTrendContent.cs` 没有该字段；现有数据在 `tEventGroup.endParam` 同时写了相同秒数。

`tTrendCustomerIncrease` 用 `dishCountRange` 表示已上架流行菜数量区间，用 `passengerFlowRate` 表示客流增幅百分比。

### 5.6 独立经营烹饪事件

```text
tManageEventFilter
→ 按 manageEventType、unlockCondition、filter 筛选
→ 按 weight 选 eventTypeParam
→ 101 正常 / 102 失败判定 / 103 表头预留大成功
→ tManageEventCookFail 决定失败率
→ tManageEventCookTime 决定时间倍率
```

当前正式数据只有 `101` 和 `102`。除非代码新增核心事件完成通知，不要让 `tPlot` 用事件条件监听这些烹饪子事件。

| Sheet | 字段关系 |
|---|---|
| `tManageEventFilter` | `manageEventType=1` 表示烹饪；`eventTypeParam` 为子事件类型；`unlockCondition→tCommonCondition.id`；`filter=1` 检查菜品总火力是否大于家具总火力；候选按 `weight` 抽取 |
| `tManageEventCookFail` | `filterParam=[比值下限,比值上限]`，代码按左开右闭匹配；`failRate` 为失败百分比；`failTimes` 为最多失败次数配置 |
| `tManageEventCookTime` | 同样按比值区间匹配；字段名 `failRate` 在这里实际表示烹饪时间倍率 |

## 6. 事件与剧情、对话、文本的关系

### 6.1 事件内部直接播放对话

| 事件字段 | 指向 |
|---|---|
| `tEventGeneralProgress.eventTypeParam[0]` | `tDialogueTable.id` |
| `tMineTalkEvent.talkParam[0]`（`talkType=1`） | `tDialogueTable.id` |
| `tMineTalkEvent.endClickEventParam[]`（`endClickEvent=101`） | `tDialogueTable.id` |
| `tEventCusterResolut.talk` | `tDialogueTable.id` |

### 6.2 事件详情直接展示文本

| 事件字段 | 指向 |
|---|---|
| `tTrendContent.posterTitle/posterContent` | `tlanguage_cn.id` |
| `tGroupMeal.orderText` | `tlanguage_cn.id` |
| `tEventCusterResolut.messageShown[]/tweet` | `tlanguage_cn.id` |
| `tMineTalkEvent.talkParam` 的失败提示项 | `tlanguage_cn.id` |

这些字段不经过 `tDialogueTable`。

### 6.3 事件结束后触发正式剧情

```text
事件完成
→ DurationEventEndEvent.eventGroupEventId=tEventGroup.id
→ tPlot.hangCondition 对应位置填 2
→ tPlot.hangConditionParam 同位置填具体 tEventGroup.id
→ tPlotStep → Timeline / 对话 / 奖励 / 任务
```

例如 `tEventGroup.id=301010601` 时，剧情参数必须填 `301010601`，不能填 Trigger `3060`、Pool 行 `30601` 或 groupId `3010106`。

### 6.4 所有对白最终进入文本表

```text
tDialogueTable.id
→ dialogueIdList[]
→ tDialogContent.id
→ tDialogContent.text → tlanguage_cn.id
→ tDialogContent.roleId → tGuideTrole.id → name → tlanguage_cn.id
```

玩家可见正文写在 `tlanguage_cn`；业务表只保存语言 ID。

## 7. 完整示例：事件 `301010101` 配置对话

当前链：

```text
条件 1010 达成
→ tEventTrigger.id=3010
   eventTriggerType=1, eventTriggerParam=[1010]
   eventPoolId=[3010], eventPoolWeight=[10000]
   logInTrigger=1, eventTriggerMax=1, limitResetType=1
   eventTag=3001

→ tEventPool.id=30101
   eventType=3010, resLv=[1,999]
   eventTypeId=[3010101], randomRule=1
   eventTypeWeight=[10000]

→ tEventGroup.id=301010101
   eventType=8, groupId=3010101, Weight=10000
   endCondition=0, eventEndRoleState=513

→ tEventGeneralProgress.id=301010101
   projectType=1, projectTypeParam=2304001
   createWay=1, createWayParam=[5,17]
   eventType=1, eventTypeParam=[202010,1]
   eventEndWay=0

→ tDialogueTable.id=202010
→ dialogueIdList=[20201001,20201002,20201003,20201004,20201005,20201006]
→ 对话结束后完成事件 301010101
```

如果替换这段对白：

1. 在 `tlanguage_cn` 准备每句正文；
2. 在 `tDialogContent` 新增单句，填写 `roleId→tGuideTrole.id` 和 `text→tlanguage_cn.id`；
3. 在 `tDialogueTable` 新建或更新对白组；
4. 把 `tEventGeneralProgress.eventTypeParam[0]` 改为该对白组 ID；
5. 第二项保持 `1` 表示播完完成事件；若为 `0`，必须另有完成方式；
6. 如果还要事件完成后播正式剧情，让 `tPlot.hangCondition=2` 监听 `301010101`。

当前没有 `tPlot` 监听 `301010101`。所以当前行为是“点击角色 → 播对白 202010 → 对话结束 → 事件完成”，不会自动追加剧情表内容。

## 8. 当前事件完成 → 剧情关系

| Trigger | 启动方式 | Pool 行 | `groupId` | 具体事件 ID | `tPlot.id` |
|---:|---|---:|---:|---:|---:|
| 2001 | 首次进入 `[100010]` | 20011 | 1001 | 1001 | 101004 |
| 2010 | 首次进入 `[101010]` | 20101 | 1010 | 1010 | 102003 |
| 2020 | 首次进入 `[101020]` | 20201 | 1020 | 1020 | 102004 |
| 2040 | 首次进入 `[101040]` | 20401 | 1040 | 1040 | 102006 |
| 2050 | 首次进入 `[101050]` | 20501 | 1050 | 1050 | 102007 |
| 2070 | 完成事件 `[1050]` | 20701 | 1070 | 1070 | 102014 |
| 3060 | 条件达成 `[230131]` | 30601 | 3010106 | 301010601 | 103008 |
| 2131 | 完成事件 `[1201]` | 21311 | 1301 | 1301 | 103014 |

本次检查中，这 8 条剧情条件都能反向找到具体事件、池和触发器。

## 9. AI 配置事件的推荐顺序

### 9.1 角色出现并说话

1. 配 `tlanguage_cn`、`tDialogContent`、`tDialogueTable`；
2. 配 `tEventGeneralProgress`；
3. 配同 ID 的 `tEventGroup`，类型 `8`；
4. 配 `tEventPool`，引用 groupId；
5. 配 `tEventTrigger`，引用池标签；
6. 明确 `eventTypeParam` 第二项是否完成事件。

### 9.2 矿下 NPC 交互

1. 配语言、单句和对白组；
2. 配 `tMineEvent` 和一条或多条 `tMineTalkEvent`；
3. 配同 ID 的 `tEventGroup`，类型 `5`；
4. 配 Pool 和 Trigger；
5. 明确由对话、数值条件、队伍条件还是 `endType=2` 完成事件。

### 9.3 事件完成后播剧情

1. 先把事件配到最终 `tEventGroup.id`；
2. 按剧情文档配置语言、对白、对白组、Timeline、`tPlotStep` 和 `tPlot`；
3. `hangCondition` 写 `2`，相同位置参数写具体事件 ID；
4. 检查事件内对白与剧情对白是否重复。

### 9.4 事件完成后启动另一个事件

1. 确定前置事件的具体 `tEventGroup.id`；
2. 后置 `tEventTrigger.eventTriggerType=6`；
3. `eventTriggerParam=[前置具体事件ID]`；
4. 后置事件仍需自己的 Pool、Group 和详情表。

## 10. 联表 QA 清单

### 核心链

- [ ] `tEventTrigger.id` 唯一。
- [ ] `eventPoolId` 与 `eventPoolWeight` 长度一致。
- [ ] 每个池标签都能匹配 `tEventPool.eventType`。
- [ ] 同池标签的等级/次数区间没有非预期重叠。
- [ ] `eventTypeId` 与规则 1/3 的权重或次数数组长度一致。
- [ ] 每个 `eventTypeId` 都能匹配至少一条 `tEventGroup.groupId`。
- [ ] 每个具体 `tEventGroup.id` 都能在正确详情表找到同 ID。
- [ ] `endCondition=1/2` 时 `endParam[0]` 是有效秒数。
- [ ] `eventTag` 能找到 `tTagLimit.id`。

### 对话、文本与剧情

- [ ] 所有事件对白组 ID 都存在于 `tDialogueTable`。
- [ ] `dialogueIdList[]` 中每句都存在于 `tDialogContent`。
- [ ] `tDialogContent.roleId` 存在于 `tGuideTrole`。
- [ ] 对白正文、角色名和事件直连文本都存在于 `tlanguage_cn`。
- [ ] JSON 二维数组使用严格格式，如 `[[1,10000],[2,5000]]`。
- [ ] 通用/挖矿对话显式填写是否在对白结束后完成。
- [ ] `tPlot` 事件参数使用具体 `tEventGroup.id`，未误用其他 ID。
- [ ] 事件内对白和事件后剧情没有重复、抢播或顺序冲突。

### 源表与公式

- [ ] 修改公式依赖行后用 Excel 重新计算并保存。
- [ ] 再次读回确认导出列没有空公式缓存或错误值。
- [ ] 辅助列的 `XLOOKUP` 错误不会被误复制到正式导出列。

## 11. 当前源表已发现的风险

1. `tEventTrigger.id=106` 重复两次，周期参数分别为 `[400,600]` 和 `[280,320]`。
2. `tEventCuster` 的 `106010101`、`107010101`、`107010102` 各重复两次；后两组刷新次数还不一致。
3. `tEventCuster` Excel 有导出字段 `thiefExdrop`，当前 `tEventCuster.cs` 没有；代码类反而有 Excel 未导出的 `orderText`。
4. `tTrendContent.duration` 在 Excel 中导出，但当前代码类没有；时长以 `tEventGroup.endParam` 为准。代码类另有 Excel 当前未导出的 `conditionId/contentWeight`。
5. `tGroupMeal.requireFood` 在 Excel 中导出，但当前代码类没有；当前代码动态生成需求菜品。
6. `tMineEvent.showBubbleType` 在 Excel 中导出，但当前代码类没有；当前运行逻辑只明确读取 `showBubble`。
7. `tManageEventCookFail/Time.filterParam` 数据含 `1.1、1.2、1.5`，但当前代码类声明为 `int[]`；需先确认导出和反序列化再改区间。
8. 特殊顾客结果表和团餐表存在 `XLOOKUP` 辅助公式的 `#N/A/#NAME?` 或空缓存，位置均在未导出辅助列；正式导出字段本次未发现受影响，但不支持 `XLOOKUP` 的环境会影响辅助显示。

## 12. 以后给 AI 的最小输入

最少只需要一句“目标 + 触发时机 + 玩家动作/结果”。例如：

```text
二楼修复后贵妇鹅出现，玩家点击后进行一段对话，对话结束后触发后续剧情；其他按项目现有经验先补一版。
```

如果有特殊要求，再在句末补充即可：

```text
硬性要求：必须使用角色 2304001；不发奖励；对白语气轻松；先生成测试副本，不改源表。
```

### 12.1 AI 应该从一句话中自动判断什么

| 描述信号 | 默认配置路线 |
|---|---|
| “播放一段剧情/过场”，没有场景对象和玩家交互 | 直接配 `tPlot` → `tPlotStep` → `tDialogueTable` |
| “某角色/物体出现，玩家点击后说话” | `eventType=8` → `tEventGeneralProgress` |
| “矿下某处出现 NPC/靠近/点击/破坏地块后触发” | `eventType=5` → `tMineEvent` + `tMineTalkEvent` |
| “团餐/订单/做菜数量” | `eventType=2` → `tGroupMeal` 及菜品辅助表 |
| “网红/霸王餐/小偷/商人来店” | `eventType=3/4/6/7` → `tEventCuster` + 结果表 |
| “流行菜/口味季/客流增加” | `eventType=1` → `tTrendContent` |
| “完成某事件后再发生下一件事” | 后件 `eventTriggerType=6`，或剧情 `hangCondition=2` |
| “烹饪失败/烹饪时间变化” | 独立的 `tManageEvent*`，不接核心事件剧情链 |

### 12.2 没写时的默认补全

AI 可以先按以下经验生成“可调整的初版”，但必须把补全值列为 `A=AI 假设`：

| 未提供内容 | 初版默认 |
|---|---|
| 是否一次性 | `eventTriggerMax=1`、`limitResetType=1` |
| 登录补偿 | `logInTrigger=1`，仅对已有可补检类型生效 |
| 权重 | 单个候选统一填 `10000`；数组按位置对齐 |
| 餐厅等级 | `[1,999]`，除非描述明确限定等级 |
| 具体事件筛选 | 不填 `tEventGroup.filter`，先保证可触发 |
| 事件标签 | 主线优先参考 `2000`，独立事件优先参考 `3001`；有同类专用标签时沿用同类配置 |
| 通用对话完成 | `eventTypeParam=[对白组ID,1]`，对白播完完成事件 |
| 事件结束后的奖励 | 未提到就不配奖励，不擅自发放道具或金币 |
| 对白坐标 | 通用对象先参考同类 `[5,17]`；矿下按关卡和邻近事件推导 |
| 缺少条件 ID | 优先寻找描述中对应的现有 `tCommonCondition`；找不到时生成测试占位/手动触发方案并标记待替换，不伪装成正式条件 |
| 缺少 ID | 读取现有占用段和父 ID 构成，选未占用的同类 ID；不使用随意的 `99/9000/999999` |

“先补一版”不等于把假设写成正式规则。AI 的输出必须分成：策划明确值、复用的现有值、推导值、AI 假设值。

### 12.3 最小输入下 AI 的固定输出

即使用户只给一句话，AI 也应返回以下 5 项，方便用户快速调整：

1. **配置判断**：这是直接剧情、事件内对白，还是事件完成后剧情。
2. **表和 ID 清单**：将新增/复用哪些表，最终具体 `tEventGroup.id` 是什么。
3. **初版配置**：按 Trigger → Pool → Group → 详情 → 对话/文本 → Plot 顺序列出。
4. **假设清单**：所有 AI 自行补的条件、坐标、次数、权重、时长、奖励和资源。
5. **调整入口**：告诉用户改“触发条件、是否完成事件、对白、奖励、后续剧情”分别改哪一列。

默认先生成测试副本并保留源表不变。AI 新增或修改的事件、剧情、对话、文本和依赖配置，只能写入输出副本；草案位置按目标 Sheet schema 和审核可追踪性决定，不强制放在 `END` 行下方。

副本中的配置仍须满足正式字段结构、ID 构成、JSON、外键和 `tlanguage_cn` 引用规则。若目标 Sheet 存在 `END` 导出截止标记，必须在副本中保留其位置和语义，但不得为了满足旧流程移动或新增 `END`。需要进入正式区时，只能交给人工/项目发布流程；AI 不直接修改正式文件、移动草案或执行正式导表。

## 13. 可直接给 AI 的任务模板

```text
请按《事件配置说明_给AI使用.md》和《剧情配置说明_给AI使用.md》配置 Bubble 项目事件。

事件需求：
- 名称：
- 类型：流行 / 团餐 / 特殊顾客 / 霸王餐 / 挖矿 / 商人 / 通用对话交互
- 启动信号：
- 额外解锁条件：
- 触发次数与刷新周期：
- 并发标签与满额处理：
- 事件详情：角色、坐标/关卡、筛选、奖励、持续时间、完成方式
- 事件内对白或直连文本：
- 是否在完成后触发剧情：

要求：
1. 先读当前 Excel 和 trunk 代码，不要只按字段名猜。
2. 先列出新建/复用 ID，不得冲突。
3. 按 Trigger → Pool 标签 → groupId → 具体 tEventGroup.id → 同 ID 详情表配置。
4. 事件内对白从详情表引用 tDialogueTable；正式剧情用 tPlot 监听具体事件 ID。
5. 所有玩家可见文字进入 tlanguage_cn。
6. 不编造未知的正式 ID、条件、奖励、坐标或资源名；列为待确认。
7. 修改后检查唯一性、引用、数组长度、JSON、公式缓存和剧情可达性。
8. 输出改动清单、完整引用链、验证结果和待确认项。
9. 所有新增/修改配置先写在输出副本中，位置按目标 Sheet schema 决定；正式源表和正式文件始终只读。若需激活，由人工/项目发布流程处理。
```

## 14. 代码核对入口

- `Code/BubteaHam_trunk/Assets/GameAssets/Scripts/Game/Module/Event/EventSystemHelper.cs`
- `Code/BubteaHam_trunk/Assets/GameAssets/Scripts/Game/Define/EnumDefine.cs`
- `Code/BubteaHam_trunk/Assets/GameAssets/Scripts/Game/Common/PlotSystem/PlotModel.cs`
- `Code/BubteaHam_trunk/Assets/GameAssets/Scripts/Game/Module/Event/EventNpcManager.cs`
- `Code/BubteaHam_trunk/Assets/GameAssets/Scripts/Game/Module/Entity/Entities/EnityEventNPC.cs`
- `Code/BubteaHam_trunk/Assets/GameAssets/Scripts/Game/Module/Mining/Runtime_Event/MiningEventRunner.cs`
- `Code/BubteaHam_trunk/Assets/GameAssets/Scripts/Game/Module/Mining/Runtime_Event/MiningTalkEventEntity.cs`
- `Code/BubteaHam_trunk/Assets/GameAssets/Scripts/Game/Module/GroupOrder/Model/GroupOrderModel.cs`
- `Code/BubteaHam_trunk/Assets/GameAssets/Scripts/Game/Module/SpecialCustomer/Model/SpecialCustomerModel.cs`
- `Code/BubteaHam_trunk/Assets/GameAssets/Scripts/Game/Module/Entity/Entities/EntityEventCustomer.cs`
- `Code/BubteaHam_trunk/Assets/GameAssets/Scripts/Game/Module/Operation/CookingHelper.cs`

> 结论：事件先由 Trigger、Pool、Group 选出具体事件，再由同 ID 详情表执行玩法；事件内部可以直接引用对白或文本，完成后则用具体 `tEventGroup.id` 触发后续事件或正式剧情。
