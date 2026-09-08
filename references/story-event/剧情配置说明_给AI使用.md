# Bubble 项目剧情配置说明（给策划与 AI 使用）

> 审阅日期：2026-09-01  
> 数据来源：`J_剧情表_tPlot.xlsx`、`D_对话表_tDialogueTable.xlsx`、`0W_文本表_tlanguage_cn.xlsx`、`S_事件表_tEventTable.xlsx` 及当前 `BubteaHam_trunk` 运行时代码。  
> 本文描述的是当前版本的实际配置和代码行为；未修改任何源 Excel。
> 事件触发、事件详情和全量事件联表规则另见：[事件配置说明_给AI使用.md](./事件配置说明_给AI使用.md)。
> 日常需求统一填写到根目录的 [剧情事件需求池.xlsx](./剧情事件需求池.xlsx)，完整接单、草案、QA、激活和归档流程见 [剧情事件AI配置工作流.md](./剧情事件AI配置工作流.md)；`剧情事件AI输入模板/` 仅保留作旧版兼容资料。

## 1. 一句话理解整个剧情系统

Bubble 的剧情不是配在一张表里，而是由“触发条件、步骤编排、对白内容、角色信息、语言文本”五层数据串起来：

```text
任务 / 事件 / 引导 / 场景条件 / 程序主动调用
                    │
                    ▼
              tPlot（剧情总表）
                    │ plotStep
                    ▼
            tPlotStep（步骤编排）
              ├─ type 1 ─► tDialogueTable（对白组）
              │                 │ dialogueIdList
              │                 ▼
              │          tDialogContent（单句对白）
              │             ├─ roleId ─► tGuideTrole ─► tlanguage_cn（角色名）
              │             └─ text ──────────────────► tlanguage_cn（对白文本）
              ├─ type 2 ─► tPlotTimeLine（Timeline）
              ├─ type 4/5 ─► tCommonDrop（奖励）
              └─ type 6 ─► tTask（发任务）
```

其中，“事件完成后播放剧情”的事件侧链路是：

```text
tEventTrigger
→ 按标签选择 tEventPool
→ 按 groupId 选择 tEventGroup 中的一条具体事件
→ 事件执行并结束
→ DurationEventEndEvent.eventGroupEventId = tEventGroup.id
→ tPlot.hangCondition=2、hangConditionParam=[同一个 tEventGroup.id]
```

最常见的一条链是：

```text
tPlot.id
→ tPlot.plotStep[]
→ tPlotStep.stepType=1、stepTypeParam=tDialogueTable.id
→ tDialogueTable.dialogueIdList[]
→ tDialogContent.text
→ tlanguage_cn.id
```

因此，新增剧情时不能只新增对白，也不能只新增 `tPlot`。每一层引用都必须存在，剧情才会完整执行。

## 2. 当前配置规模

| 工作簿 | 导出 Sheet | 当前数据量 | 作用 |
|---|---:|---:|---|
| `J_剧情表_tPlot.xlsx` | `tPlot` | 32 条 | 剧情入口、触发条件、场景和步骤列表 |
|  | `tPlotStep` | 51 条 | 按顺序执行的对白、Timeline、奖励等步骤 |
|  | `tPlotTimeLine` | 11 条 | Timeline 资源、播放方式和关闭规则 |
| `D_对话表_tDialogueTable.xlsx` | `tDialogueTable` | 237 条 | 把若干单句对白组成一组，并控制暂停、跳过、奖励 |
|  | `tDialogContent` | 563 条 | 单句对白的角色、文本、位置、遮罩、动画等 |
|  | `tGuideTrole` | 47 条 | 剧情/引导用角色立绘与角色名 |
| `0W_文本表_tlanguage_cn.xlsx` | `tlanguage_cn` | 5175 条 | 中文文本正文；其他表只保存语言 ID |
| `S_事件表_tEventTable.xlsx` | `tEventTrigger` | 39 个非空数据行、38 个唯一 ID | 决定事件何时触发、选哪个事件池标签及次数限制 |
|  | `tEventPool` | 111 条 | 按餐厅等级、完成次数和抽取规则选择事件组 |
|  | `tEventGroup` | 170 条 | 具体事件候选；其 `id` 是剧情监听的事件完成 ID |
|  | `tTagLimit` | 8 条 | 控制同标签事件同时存在的数量和超限处理 |

当前 32 条 `tPlot` 按 ID 前缀分为：

- `1xxxxx`：15 条自动/主线剧情。
- `2xxxxx`：13 条任务完成后主动播放的剧情。
- `3xxxxx`：4 条顾客好感剧情。

这些是现有数据的使用习惯，不是代码对 ID 首位的硬编码判断。真正决定剧情如何启动的是触发配置和程序调用。

## 3. Excel 的通用导出规则

三个工作簿都遵守项目配置表的通用规则：

- 只有名称以小写 `t` 开头的 Sheet 会导出。
- 前 6 行是表头、字段名、类型和说明；正式数据从第 7 行开始。
- A 列是策划备注列，不参与导出。
- B 列通常是主键 `id`。
- 遇到字段名为 `END` 的列后停止导出。
- `arr` 字段必须写合法 JSON 数组，例如 `[102004010,102004020]`。
- 代码中作为二维数组解析的 `str` 字段，也必须写严格 JSON，例如 `[[10001,2],[10002,1]]`，不能写 `{10001,2}` 这种伪格式。
- 所有玩家可见文字都应进入 `tlanguage_cn`，业务表只填语言 ID。
- ID 只要求在对应表内唯一，不要假设所有表共用一个全局 ID 空间。

### 3.1 AI 配置的写入位置（项目约定）

AI 帮用户新增或修改剧情、对话、文本、事件及其依赖配置时，必须遵守以下隔离规则：

1. 只修改输出目录中的工作簿副本，不修改 `策划/配置表/Table` 源表。
2. 每个目标 Sheet 都先定位 **A 列内容为 `END` 的行**；AI 生成的配置行统一写在该行下方，`END` 行本身不得移动、覆盖或删除。
3. A 列 `END` 行及其下方内容不会被导表器导出，因此这里是“AI 待确认草稿区”，不是当前可运行的正式导出区。
4. 即使写在 `END` 下方，AI 仍须按正式配置标准填写完整字段、合法 JSON、候选 ID、外键和 `tlanguage_cn` 引用，并检查与 `END` 上方正式数据是否冲突。
5. 用户明确要求“确认并转为正式配置”后，才将确认过的行移动到 `END` 上方；移动后必须重新检查 ID 唯一性、跨表引用、语言文本、公式缓存和实际导出结果。
6. 若目标 Sheet 没有 A 列 `END` 行，AI 不得自行猜测写入位置，应在副本中先标记“缺少行 END，待确认”，并报告用户。

现有表中有较多 Excel 公式用于自动拼接 ID 列表。AI 修改时可以保留公式，但交付前必须用 Excel 或兼容引擎重算、保存，并重新读回检查公式缓存结果。最稳妥的交付方式是确保导出时能读到最终的 JSON 数组值，而不只是公式文本。

## 4. `J_剧情表_tPlot.xlsx`：剧情入口与步骤

### 4.1 `tPlot`：剧情总表

一行代表一段完整剧情。

| 字段 | 类型 | 实际用途与配置规则 |
|---|---|---|
| `id` | int | 剧情 ID。现有主线多为 6 位，如 `102004`。6 位 ID 也符合当前自动收集步骤公式的前缀规则。 |
| `hangPlotId` | arr | 前置剧情 ID 列表。所有前置剧情都完成后才满足。无前置填 `[]`。 |
| `hangCondition` | arr | 自动触发条件类型列表：`1` 任务、`2` 事件组、`3` 餐厅等级、`4` 引导。多个条件是“并且”。 |
| `hangConditionParam` | arr | 与 `hangCondition` 一一对应的参数。代码类型是 `int[]`，每个条件对应一个整数，不是二维数组。例：`hangCondition=[2]`、`hangConditionParam=[1020]`。 |
| `needItem` | str | 启动前所需道具。代码按 `int[][]` 解析，必须写严格 JSON：`[[道具ID,数量],[道具ID,数量]]`。无需求建议填空字符串或项目既有空值形式。 |
| `needItemRecycle` | int | `1` 表示自动剧情成功结束后回收所需道具；`0` 不回收。程序直接调用启动的剧情不会执行这段回收逻辑。 |
| `extraCondition` | arr | 附加条件：`1` 注册天数、`2` 在线秒数、`3` 餐厅属性。多个条件是“并且”。 |
| `extraConditionParam` | str | 代码按 `int[][]` 解析，并与 `extraCondition` 对齐。类型 1/2 通常提供阈值；类型 3 使用 `[属性ID,最小值]`。必须参考同类现有行并写严格 JSON。 |
| `plotScene` | int | 限制自动剧情启动场景：`1` 餐厅、`2` 装修、`3` 挖矿、`4` 商店。 |
| `plotStep` | arr | 按顺序执行的 `tPlotStep.id` 列表。当前公式按步骤 ID 的前 6 位匹配剧情 ID。 |
| `pauseSwitch` | int | `1` 剧情期间暂停所有系统；`0` 不做全局暂停。它与对白组自己的 `isPauseGame` 不是同一个开关。 |
| `closeComponent` | int | 剧情开始时关闭的组件：`1` 挖矿角色/UI，`2` 餐厅 UI。空或 0 表示不处理。 |
| `openComponent` | int | 剧情结束时是否恢复被关闭组件：`0` 恢复，`1` 保持关闭。字段名容易产生误解，应按这个代码行为填写。 |
| `plotResourceDelete` | arr | 剧情资源释放策略。空数组表示剧情结束时销毁；`[1,引导ID]` 表示保留 Timeline 资源，直到对应引导完成。 |

#### 自动剧情的判断顺序

当前代码会把有 `hangCondition` 的剧情加入待检测集合，启动前依次检查：

1. 剧情没有完成、也没有正在执行。
2. `hangPlotId` 中所有前置剧情均已完成。
3. `hangCondition` 中所有条件均满足。
4. 当前场景与 `plotScene` 匹配。
5. `needItem` 数量足够。
6. `extraCondition` 中所有条件均满足。

重要限制：没有 `hangCondition` 的剧情不会通过这套自动检测启动。若它也没有其他代码主动调用，就会成为“表里存在但永远不播放”的剧情。

待播放集合目前使用 `HashSet` 遍历，没有剧情优先级字段，也没有可靠的固定顺序。应避免让多条自动剧情在同一时刻同时满足；若业务确实需要，应在程序层增加明确优先级。

### 4.2 两种启动路径必须区分

#### A. 自动/挂起条件启动

适合主线事件、等级、任务状态、引导完成等条件触发。它会执行完整的前置、场景、道具和附加条件检查，并在成功后记录完成状态。

#### B. `StartPlotById` 程序直接启动

当前主动启动只检查“此刻没有剧情正在跑”和“剧情 ID 存在”，会绕过：

- 是否已经完成；
- `hangPlotId`；
- `hangCondition`；
- `plotScene`；
- `needItem`；
- `extraCondition`。

因此直接启动的剧情可以重复播放，而且不会走自动剧情的 `needItemRecycle` 回收逻辑。

当前主干代码中已确认的生产入口是任务完成按钮：

```text
tTaskPlot.endButtonEffect = 2
tTaskPlot.endButtonEffectParam = tPlot.id
→ TaskViewController 调用 StartPlotById
```

`3xxxxx` 好感剧情虽然能通过 `tCustomerStory.storyId → tPlot.id` 关联，并在剧情结束后记录“已看”，但本次审阅没有在当前主干找到从顾客故事模块主动发出 `StartPlotById` 的生产代码。配置前应先向程序确认实际入口，不能只新增 `tCustomerStory.storyId` 就认定会播放。

### 4.3 `tPlotStep`：剧情步骤表

每行是一条可执行步骤，`tPlot.plotStep` 决定执行顺序。步骤是串行执行的：前一步成功，才会进入下一步；任一步骤引用缺失或执行失败，整段剧情会中止，且不会正常记为完成。

| `stepType` | 表头/枚举名称 | `stepTypeParam` 实际指向 | 当前代码行为 |
|---:|---|---|---|
| 1 | Dialog | `tDialogueTable.id` | 播放一组对白，等待对白组结束。 |
| 2 | Timeline | `tPlotTimeLine.id` | 创建、播放或关闭 Timeline。 |
| 3 | SceneAnimation | 未完成 | 当前运行代码会直接走未实现失败，不要配置。 |
| 4 | GiveItem | `tCommonDrop.dropId` | 奖励先进入队列，整段剧情全部成功后才真正发放。 |
| 5 | OpenView | `tCommonDrop.dropId` | 当前代码不是打开任意界面，而是发奖励并显示奖励弹窗；也在整段剧情成功后发放。 |
| 6 | GiveTask | `tTask.id` | 发放任务。代码支持，但 Excel 表头说明没有列出；当前数据暂未使用。 |

`blackScreen=1` 会在执行该步骤前进行黑屏过渡。

注意：不要根据枚举名称猜行为。特别是类型 5，当前实现明确是“奖励 + 弹窗”，不是通用 OpenView。

### 4.4 `tPlotTimeLine`：Timeline 配置

| 字段 | 用途 |
|---|---|
| `id` | Timeline 配置 ID，由 `tPlotStep.stepTypeParam` 引用。 |
| `timeLinePath` | Timeline/Director prefab 资源路径。 |
| `endTime` | 结束时间，单位毫秒；`0` 表示按完整 Timeline 播放。 |
| `createWay` | 创建方式：`1` UI 层；`2` 餐厅坐标；`3` 挖矿坐标。 |
| `createWayParam` | 创建参数，必须参考相同 `createWay` 的现有行。 |
| `clickToClose` | 是否允许点击关闭。 |
| `closeToDelete` | 关闭时是否删除已创建的 Timeline 资源。 |
| `blackScreen` | Timeline 步骤自身的黑屏控制。 |

一个常见做法是：第一条 Timeline 配置负责创建并播放，后续另一条 Timeline 配置负责关闭或收尾。因此看到同一剧情连续引用多个 Timeline 步骤，不一定是重复配置。

## 5. `D_对话表_tDialogueTable.xlsx`：对白组、单句和角色

### 5.1 `tDialogueTable`：对白组

一行代表一次完整的对话会话。

| 字段 | 实际用途与注意点 |
|---|---|
| `id` | 对白组 ID，由 `tPlotStep.stepTypeParam` 引用。剧情对白通常为 6 位。 |
| `dialogueIdList` | 按顺序播放的 `tDialogContent.id` 数组。当前公式通常按单句 ID 前 6 位自动归组。 |
| `dialogReward` | 对白组奖励，指向 `tCommonDrop.dropId`。 |
| `rewardPopup` | Excel 中存在，但当前 `tDialogueTable.cs` 没有这个字段，控制器也未读取。当前版本不要依赖它生效。 |
| `rewardNode` | 奖励发放节点：`-1` 开始时、`0` 结束时、或指定某个 `tDialogContent.id` 播放后。 |
| `isPauseGame` | 语义与字段名直觉相反：`0` 会暂停游戏，`1` 不暂停。 |
| `skippable` | `1` 可跳过；跳过会进入正常结束流程，因此结束节点奖励仍会触发。 |
| `priority` | 数字越大越靠前；同优先级保持进入队列的先后顺序。 |

运行时会忽略 `dialogueIdList` 中不存在的单句 ID，只把有效单句组成会话；若一个有效单句也没有，则整组创建失败。同一个对白组 ID 正在播放或已经排队时，不能重复入队。

### 5.2 `tDialogContent`：单句对白

| 字段 | 实际用途与注意点 |
|---|---|
| `id` | 单句对白 ID。现有剧情习惯为“6 位对白组 ID + 2 位句序”，如 `10204001`。 |
| `type` | `1` 底部对白；`2` 侧边/聊天对白；`3` 场景对白。 |
| `dialogBg` | 对话框背景 Atlas Sprite 名称。 |
| `typeParam` | 对 type 1/2 常用：`1` 左、`2` 右。 |
| `roleId` | 实际指向 `tGuideTrole.id`，不是普通 `tRole`。 |
| `text` | 指向 `tlanguage_cn.id`，保存对白正文。 |
| `textDelay` | 文本开始显示前的延迟。代码类型为 `float`，可以填小数。 |
| `textSpeed` | 打字速度。代码类型为 `float`，可以填小数。 |
| `offsetPosition` | 场景对白偏移。type 3 使用时数组长度必须恰好为 2。 |
| `mask` | `0` 无遮罩；`1` 透明遮罩；`2` 半透明遮罩。 |
| `animation` | 立绘/对话表现动画开关或类型，沿用同类对话。 |
| `showPic` | 横幅或展示图资源。当前代码只在 `type=1` 时加载此图。 |
| `picPosition` / `picSize` / `picAnime` | 展示图位置、尺寸和动画配置。 |
| `animationName` | type 2 使用的聊天样式/动画名；空值会回退为 `UIDialogChatStyle_Default2`。 |

代码类还定义了 `sfxId`，但当前 Excel 没有该字段。不要自行给表加列；若要支持对白音效，应先由程序确认导出 Schema 和运行逻辑。

### 5.3 `tGuideTrole`：剧情角色

虽然用户通常只关注对白表，但 `tGuideTrole` 是对白链路的必要组成：

```text
tDialogContent.roleId
→ tGuideTrole.id
→ tGuideTrole.name
→ tlanguage_cn.id
```

它还保存角色表情/立绘资源和阴影配置。新增对白角色前，必须先确认已有 `tGuideTrole` 是否可复用；没有时再新增，并同步分配角色名语言 ID。

## 6. `0W_文本表_tlanguage_cn.xlsx`：所有可见文本

`tlanguage_cn` 的核心字段只有：

- `id`：语言 ID；
- `words`：中文正文；
- 其余 `tips`、备注列：策划说明，不导出。

代码通过 `LanguageUtility` 查找语言 ID。填 `0` 或查不到时，会回退到语言 ID `10000000` 并记录错误。因此语言引用缺失可能不会立刻崩溃，但玩家会看到兜底文本，仍属于配置错误。

现有 ID 首位大致有以下历史分段：

| 首位 | 现有用途习惯 |
|---:|---|
| 1 | 道具/程序通用文本 |
| 2 | 公共文本 |
| 3 | 模块文本 |
| 4 | 角色相关 |
| 5 | 家具 |
| 6 | 食物 |
| 7 | 任务/角色名等历史区段 |
| 8 | 剧情对白 |
| 9 | 特殊顾客 |

历史数据中存在 4～9 位混合 ID，不能简单执行“全表最大 ID + 1”。新增剧情对白时，应先找到目标章节或模块当前使用的 `8...` 区段，再在该区段内连续分配，并检查是否冲突。

`words` 可以包含富文本标签或占位符。复制或改写时必须保留标签闭合、变量名和占位符数量。

## 7. ID 编号和自动归组习惯

### 7.1 推荐保持的编号结构

以剧情 `102004` 为例：

```text
tPlot.id                102004
tPlotStep.id            102004010、102004020、102004030……
tDialogueTable.id       102040
tDialogContent.id       10204001、10204002、10204003……
tlanguage_cn.id         810204001、810204002、810204003……
```

这套结构的价值不只是可读性：当前 `tPlot.plotStep` 和 `tDialogueTable.dialogueIdList` 中的部分公式正是依靠前缀匹配自动收集数据。

### 7.2 新增 ID 的原则

1. 先确认剧情所属章节、任务或顾客模块。
2. 在相同业务区段找最近的完整案例。
3. 检查目标表内是否冲突。
4. 保持同组 ID 前缀和句序连续。
5. 不使用全局 `MAX(id)+1` 作为唯一策略。
6. 不为了补空号而占用别的模块预留段。

## 8. 完整案例：主线剧情 `102004`

这条剧情能清楚展示多表关系。

### 8.1 剧情入口

`tPlot.id=102004`：

- 名称：主线剧情-2-4-鼹鼠的礼物；
- `hangCondition=[2]`：由事件组触发；
- `hangConditionParam=[1020]`；
- `plotScene=3`：挖矿场景；
- `pauseSwitch=1`；
- `plotStep=[102004010,102004020,102004030,102004040]`。

### 8.2 四个步骤

| 顺序 | `tPlotStep.id` | 类型 | 参数 | 实际行为 |
|---:|---:|---:|---:|---|
| 1 | 102004010 | 2 | 1020 | 播放 `tPlotTimeLine.id=1020`。 |
| 2 | 102004020 | 1 | 102040 | 播放 `tDialogueTable.id=102040`。 |
| 3 | 102004030 | 2 | 10201 | 执行收尾/关闭 Timeline。 |
| 4 | 102004040 | 5 | 2201010 | 整段剧情成功后发放该 `tCommonDrop` 并弹奖励界面。 |

Timeline `1020` 使用资源：

```text
Timeline/Plot1020/Director1020.prefab
```

其 `endTime=417`、`createWay=1`、`createWayParam=[8]`、`closeToDelete=1`。

### 8.3 对白组和第一句

`tDialogueTable.id=102040`：

- `dialogueIdList=[10204001,10204002,10204003,10204004]`；
- `isPauseGame=1`：对白组自身不暂停游戏；
- `skippable=1`：可跳过。

第一句 `tDialogContent.id=10204001`：

- `type=1`；
- `roleId=11240101`；
- `text=810204001`；
- `textDelay=0.5`；
- `textSpeed=0.025`；
- `mask=2`；
- `animation=1`。

引用继续展开：

```text
roleId 11240101
→ tGuideTrole.name 71010101
→ tlanguage_cn.words “奶茶鼠”

text 810204001
→ tlanguage_cn.words “太好了是宝箱！咦，贴了个纸条？让鼠看看……”
```

这就是一条可播放剧情从触发到最终文本的完整闭环。

## 9. AI 新增剧情时的推荐配置顺序

不要从 `tPlot` 顶层开始随意填引用。推荐按“叶子数据先准备、顶层最后串联”的顺序：

1. **确认启动方式**：自动条件触发，还是任务/程序直接启动。
2. **选择对标案例**：找相同场景、相同步骤组合和相同对白 UI 类型的现有剧情。
3. **分配 ID**：先列出所有新 ID 和所属表，检查冲突。
4. **配置语言文本**：在 `tlanguage_cn` 目标区段新增角色名或对白正文。
5. **配置角色**：复用或新增 `tGuideTrole`。
6. **配置单句对白**：新增 `tDialogContent`，逐句引用角色和语言 ID。
7. **配置对白组**：新增 `tDialogueTable`，按顺序填写 `dialogueIdList`。
8. **配置 Timeline/奖励/任务**：只在剧情需要时新增或引用对应表。
9. **配置步骤**：新增 `tPlotStep`，明确每一步类型和参数指向。
10. **配置剧情总表**：最后新增 `tPlot`，填写触发、场景和步骤列表。
11. **配置外部入口**：若是任务剧情，同步配置 `tTaskPlot`；若是顾客故事，确认程序入口及 `tCustomerStory`。
12. **重算公式并读回验证**：确认每个数组、每个引用和每条正文都能从文件中重新读取。

### 不建议 AI 做的事

- 不要只看 Excel 表头猜运行行为。
- 不要把 `hangConditionParam` 写成二维数组。
- 不要把 `needItem` 写成花括号伪数组。
- 不要把 `tDialogContent.roleId` 指到普通 `tRole`。
- 不要把 `stepType=5` 当成任意开界面。
- 不要依赖 `rewardPopup` 当前生效。
- 不要配置尚未实现的 `stepType=3`。
- 不要只新增 `3xxxxx` 和 `tCustomerStory` 就默认好感剧情一定会主动播放。
- 不要在未重算公式、未读回校验时宣称配置完成。

## 10. 交付前 QA 清单

### 10.1 结构和格式

- [ ] 只修改目标行、目标 Sheet，没有改表头、列顺序和 Sheet 名。
- [ ] 所有新增主键在各自表内唯一。
- [ ] 所有 `arr` 都是合法 JSON 数组。
- [ ] `needItem`、`extraConditionParam` 是代码可解析的严格 JSON。
- [ ] 公式已重算并保存，重新打开后能读到最终结果。

### 10.2 引用完整性

- [ ] `tPlot.plotStep[]` 中每个 ID 都存在于 `tPlotStep`。
- [ ] 对白步骤参数都存在于 `tDialogueTable`。
- [ ] Timeline 步骤参数都存在于 `tPlotTimeLine`。
- [ ] 奖励步骤参数都存在于 `tCommonDrop`。
- [ ] 发任务步骤参数都存在于 `tTask`。
- [ ] `tDialogueTable.dialogueIdList[]` 中每句都存在于 `tDialogContent`。
- [ ] `tDialogContent.roleId` 都存在于 `tGuideTrole`。
- [ ] `tDialogContent.text` 和 `tGuideTrole.name` 都存在于 `tlanguage_cn`。

### 10.3 运行逻辑

- [ ] 自动剧情至少有一个有效 `hangCondition`。
- [ ] `hangCondition` 与 `hangConditionParam` 数量一致。
- [ ] 自动剧情 `plotScene` 与触发时场景一致。
- [ ] 同一时刻不会有多条无优先级剧情同时满足。
- [ ] 直接启动剧情已接受“可重复播放、绕过条件、不会回收 needItem”的行为。
- [ ] `isPauseGame` 按 `0=暂停、1=不暂停` 检查。
- [ ] 可跳过对白的奖励节点经过设计确认。
- [ ] Timeline 资源路径、创建方式和销毁策略均由运行环境验证。

### 10.4 文本和表现

- [ ] 语言 ID 位于正确业务区段，未与现有 ID 冲突。
- [ ] 富文本标签与占位符完整。
- [ ] 句序、角色、左右位置、遮罩、延迟和速度符合剧本。
- [ ] type 3 的 `offsetPosition` 恰好为两个值。
- [ ] `showPic` 只在当前代码支持的 type 1 场景使用。

## 11. 当前源表已发现的问题与待确认项

以下问题来自本次对实际 Excel 数据的跨表读回，不是泛化建议。

### 11.1 会让当前 `tPlot` 链路中止的缺失引用

缺失对白组：

| 剧情 | 步骤 | 缺失的 `tDialogueTable.id` |
|---:|---:|---:|
| 102017 | 102017030 | 102170 |
| 103010 | 103010020 | 103100 |

缺失 Timeline：

| 剧情 | 步骤 | 缺失的 `tPlotTimeLine.id` |
|---:|---:|---:|
| 102017 | 102017020 | 1050 |
| 103007 | 103007030 | 1070 |
| 103010 | 103010010 | 1080 |
| 103010 | 103010030 | 1090 |
| 103018 | 103018010 | 1100 |
| 103018 | 103018020 | 1110 |

### 11.2 触发配置异常

- `103018` 配置了 `hangCondition=[1]`（任务条件），但对应任务参数为空，自动条件无法正常判断。
- `102016`、`102017`、`103007`、`103010`、`103015` 没有有效 `hangCondition`。它们不会进入自动条件启动链；需确认是否有未检出的外部入口，或是否漏配触发条件。
- 当前代码没有明确的待播放剧情优先级，多条剧情同时满足时顺序不可靠。

### 11.3 对话数据中的孤立缺失引用

- `tDialogueTable.id=1000203` 引用了不存在的 `tDialogContent.id=30022009`。该对白组被剧情 `102014` 引用；运行时会跳过缺失的这一句，只播放组内其他有效单句，因此不会像“整个对白组不存在”那样直接让该步骤失败，但会造成剧情少一句。
- 当前 32 条 `tPlot` 能走到的对白内容中，未发现缺失的 `tlanguage_cn` 或 `tGuideTrole` 引用。

### 11.4 Schema 与代码不一致

- `tDialogueTable.rewardPopup` 在 Excel 有字段，但当前代码类和控制器不读取。
- `tDialogContent.sfxId` 在代码类中存在，但当前 Excel 没有字段。
- `tPlotStep.stepType=6` 代码支持发任务，但 Excel 表头说明缺少该类型。
- `tPlotStep.stepType=3` 有枚举和表头定义，但当前执行逻辑未实现。

这些差异应由策划和程序共同决定是“修表头、修代码，还是废弃字段”，AI 不应自行补齐 Schema。

## 12. 当前 32 条剧情索引

| ID | 名称 | 当前入口/条件摘要 | 场景 | 步骤摘要 |
|---:|---|---|---|---|
| 101004 | 主线剧情-1-4-天坑逃生 | 事件组 1001 | 挖矿 | Timeline |
| 102003 | 主线剧情-2-3-纸条弹窗 | 事件组 1010 | 挖矿 | Timeline |
| 102004 | 主线剧情-2-4-鼹鼠的礼物 | 事件组 1020 | 挖矿 | Timeline→对白→Timeline→奖励弹窗 |
| 102006 | 主线剧情-2-6-鼹鼠的失踪 | 事件组 1040 | 挖矿 | Timeline→对白→Timeline |
| 102007 | 主线剧情-2-7-1-救出鼹鼠后的感谢 | 事件组 1050 | 挖矿 | 对白 |
| 102014 | 主线剧情-2-14-大索道层-开放 | 事件组 1070 | 挖矿 | Timeline→对白（缺 1 句）→Timeline |
| 102016 | 主线剧情-2-16-备用发电机 | 未配置自动条件 | 餐厅 | 对白 |
| 102017 | 主线剧情-2-17-米吱林到访 | 未配置自动条件 | 餐厅 | Timeline→缺失 Timeline→缺失对白组 |
| 103005 | 主线剧情-3-5-这就是仓鼠癖！ | 引导 42010 | 餐厅 | 对白 |
| 103007 | 独立事件-网红探店-网红初访 | 未配置自动条件 | 餐厅 | Timeline→对白→缺失 Timeline |
| 103008 | 独立事件-网红探店-鼠不可忍 | 事件组 301010601 | 餐厅 | 对白→Timeline→对白→Timeline |
| 103010 | 主线剧情-3-10-团餐订单 | 未配置自动条件 | 餐厅 | 缺失 Timeline→缺失对白组→缺失 Timeline |
| 103014 | 主线剧情-3-14-睿智鼠的加入前提-放大镜 | 事件组 1301 | 挖矿 | 奖励弹窗 |
| 103015 | 主线剧情-3-15-睿智鼠到店-鼠鼠奖励 | 未配置自动条件 | 挖矿 | 发奖励 |
| 103018 | 主线剧情-3-18-米之林评审 | 任务参数为空 | 餐厅 | 两个缺失 Timeline |
| 200201 | 剧情任务2-1_完成对话 | 程序直接启动 | 不限 | 对白 |
| 200202 | 剧情任务2-2_完成对话 | 程序直接启动 | 不限 | 对白 |
| 200302 | 剧情任务3-2_完成对话 | 程序直接启动 | 不限 | 对白 |
| 200303 | 剧情任务3-3_完成对话 | 程序直接启动 | 不限 | 对白 |
| 200401 | 剧情任务4-1_完成对话 | 程序直接启动 | 不限 | 对白 |
| 200402 | 剧情任务4-2_完成对话 | 程序直接启动 | 不限 | 两组对白 |
| 200403 | 剧情任务4-3_完成对话 | 程序直接启动 | 不限 | 对白 |
| 200501 | 剧情任务5-1_完成对话 | 程序直接启动 | 不限 | 对白 |
| 200502 | 剧情任务5-2_完成对话 | 程序直接启动 | 不限 | 对白 |
| 200503 | 剧情任务5-3_完成对话 | 程序直接启动 | 不限 | 对白 |
| 200601 | 剧情任务6-1_完成对话 | 程序直接启动 | 不限 | 对白 |
| 200602 | 剧情任务6-2_完成对话 | 程序直接启动 | 不限 | 对白 |
| 200603 | 剧情任务6-3_完成对话 | 程序直接启动 | 不限 | 对白 |
| 300101 | 阿狗好感对话1 | 顾客故事入口待程序确认 | 不限 | 对白 |
| 300102 | 阿狗好感对话2 | 顾客故事入口待程序确认 | 不限 | 对白 |
| 300103 | 阿狗好感对话3 | 顾客故事入口待程序确认 | 不限 | 对白 |
| 300104 | 阿狗好感对话4 | 顾客故事入口待程序确认 | 不限 | 对白 |

## 13. 可直接交给 AI 的剧情配置提示词

下面这段可以复制给 AI，再附上具体剧本和目标文件：

```text
请为 Bubble 项目配置一段剧情。开始前必须读取：
1. 策划/配置表/Table/J_剧情表_tPlot.xlsx
2. 策划/配置表/Table/D_对话表_tDialogueTable.xlsx
3. 策划/配置表/Table/0W_文本表_tlanguage_cn.xlsx
4. 如果剧情由事件完成触发：策划/配置表/Table/S_事件表_tEventTable.xlsx
5. 策划/配置表/剧情配置说明_给AI使用.md

如表头说明与运行时代码可能不一致，请继续读取当前 BubteaHam_trunk 中的
PlotController、PlotModel、PlotRunner、DialogModel、DialogController 以及对应 tTable 类，
以当前代码真实行为为准，并在交付说明中列出发现的不一致。

我的剧情需求：
- 剧情名称：<填写>
- 所属主线/任务/顾客：<填写>
- 启动方式：<自动条件 / 任务完成按钮 / 顾客故事 / 程序直接调用>
- 前置剧情：<填写或无>
- 触发条件及参数：<填写>
- 播放场景：<餐厅 / 装修 / 挖矿 / 商店 / 不限>
- 是否全局暂停：<是/否>
- 是否可跳过对白：<是/否>
- 是否需要 Timeline：<资源与播放要求>
- 是否发奖励：<tCommonDrop ID 或奖励需求>
- 剧本：<逐句写角色、台词、左右位置、表现要求>

执行要求：
1. 先找相同场景、相同步骤结构和相同 UI 类型的现有剧情作为对标，不要套通用模板。
2. 先输出“计划新增/复用的 ID 清单”和完整引用链，检查冲突后再写表。
3. 所有可见文字必须写入 tlanguage_cn；tDialogContent.text 只填语言 ID。
4. tDialogContent.roleId 必须引用 tGuideTrole，不要引用普通 tRole。
5. arr 和二维参数必须是严格 JSON；hangConditionParam 是一维 int 数组。
6. 不得使用未实现的 stepType=3；stepType=5 按奖励弹窗处理；stepType=6 只有确认要发任务时使用。
7. 明确区分自动启动和 StartPlotById 直接启动，不能假设两者检查逻辑相同。
8. 不要直接覆盖源文件。先复制为新的交付版文件，保留原有格式、公式、Sheet 名和表头。
9. 写入后重新打开三个工作簿，逐项验证 tPlot→tPlotStep→对白/Timeline/奖励→角色→语言引用。
10. 对公式列执行重算或确保缓存结果可读，并扫描 #REF!、#DIV/0!、#VALUE!、#NAME?。
11. 最终交付必须包含：修改后的工作簿、变更清单、ID 清单、引用完整性检查、公式检查、仍需程序确认的事项。
12. 如果触发入口、Timeline 资源、奖励 ID 或角色资源没有正式依据，不要编造；请标为待确认。
13. 如果使用事件触发，tPlot.hangConditionParam 必须填写最终具体的 tEventGroup.id；不要误填 tEventTrigger.id、tEventPool.id 或 tEventGroup.groupId。
```

## 14. 本次理解所依据的主要代码

剧情系统：

- `Code/BubteaHam_trunk/Assets/GameAssets/Scripts/Game/Common/PlotSystem/PlotController.cs`
- `Code/BubteaHam_trunk/Assets/GameAssets/Scripts/Game/Common/PlotSystem/PlotModel.cs`
- `Code/BubteaHam_trunk/Assets/GameAssets/Scripts/Game/Common/PlotSystem/PlotRunner.cs`
- `Code/BubteaHam_trunk/Assets/GameAssets/Scripts/Game/Common/PlotSystem/PlotData.cs`
- `Code/BubteaHam_trunk/Assets/GameAssets/Scripts/Game/Define/EnumDefine.cs`

对白系统：

- `Code/BubteaHam_trunk/Assets/GameAssets/Scripts/Game/Module/Dialog/DialogModel.cs`
- `Code/BubteaHam_trunk/Assets/GameAssets/Scripts/Game/Module/Dialog/DialogController.cs`
- `Code/BubteaHam_trunk/Assets/GameAssets/Scripts/Game/Module/Dialog/DialogDefine.cs`

配置类与外部入口：

- `Code/BubteaHam_trunk/Assets/GameAssets/Scripts/Game/Tables/tPlot.cs`
- `Code/BubteaHam_trunk/Assets/GameAssets/Scripts/Game/Tables/tPlotStep.cs`
- `Code/BubteaHam_trunk/Assets/GameAssets/Scripts/Game/Tables/tPlotTimeLine.cs`
- `Code/BubteaHam_trunk/Assets/GameAssets/Scripts/Game/Tables/tDialogueTable.cs`
- `Code/BubteaHam_trunk/Assets/GameAssets/Scripts/Game/Tables/tDialogContent.cs`
- `Code/BubteaHam_trunk/Assets/GameAssets/Scripts/Game/Tables/tGuideTrole.cs`
- `Code/BubteaHam_trunk/Assets/GameAssets/Scripts/Game/Common/Utility/LanguageUtility.cs`
- `Code/BubteaHam_trunk/Assets/GameAssets/Scripts/Game/Module/Task/TaskViewController.cs`
- `Code/BubteaHam_trunk/Assets/GameAssets/Scripts/Game/Module/Collection/CollectionModel.cs`

事件系统：

- `Code/BubteaHam_trunk/Assets/GameAssets/Scripts/Game/Module/Event/EventSystemHelper.cs`
- `Code/BubteaHam_trunk/Assets/GameAssets/Scripts/Game/Module/Event/EventController.cs`
- `Code/BubteaHam_trunk/Assets/GameAssets/Scripts/Game/Module/Event/Model/EventModel.cs`
- `Code/BubteaHam_trunk/Assets/GameAssets/Scripts/Game/Module/Event/Model/EventData.cs`
- `Code/BubteaHam_trunk/Assets/GameAssets/Scripts/Game/Module/Event/EventNpcManager.cs`
- `Code/BubteaHam_trunk/Assets/GameAssets/Scripts/Game/Tables/tEventTrigger.cs`
- `Code/BubteaHam_trunk/Assets/GameAssets/Scripts/Game/Tables/tEventPool.cs`
- `Code/BubteaHam_trunk/Assets/GameAssets/Scripts/Game/Tables/tEventGroup.cs`
- `Code/BubteaHam_trunk/Assets/GameAssets/Scripts/Game/Define/EventCollection/DiningEventCollection.cs`

后续代码或 Excel Schema 发生变化时，应重新核对本文第 4、5、11、15 节，尤其是直接启动逻辑、步骤类型、对白奖励字段、事件触发枚举、Pool/Group 匹配键和顾客好感剧情入口。

## 15. `S_事件表_tEventTable.xlsx` 与剧情配置的关系

### 15.1 最重要的结论

事件表和剧情表之间只有一个真正关键的对接键：

```text
tEventGroup.id
= DurationEventEndEvent.eventGroupEventId
= tPlot.hangConditionParam 中事件条件对应的参数
```

当 `tPlot.hangCondition=[2]` 时，`hangConditionParam` 应填写最终具体的 `tEventGroup.id`。

以下三个值都不能直接填给剧情：

- `tEventTrigger.id`：事件触发配置 ID，只表示哪套触发规则启动了事件。
- `tEventPool.id`：事件池行主键，只用于池自身的序列/分布状态记录。
- `tEventGroup.groupId`：事件候选组的分组键；一个 groupId 可以筛出多条具体 `tEventGroup.id`。

对于只有一个候选的旧主线事件，`tEventGroup.id` 和 `groupId` 经常相同，所以很容易误以为它们永远等价。独立事件 `301010601` 就是反例：

```text
tEventPool.eventTypeId = [3010106]       ← 这是 groupId
tEventGroup.groupId = 3010106
tEventGroup.id = 301010601               ← 剧情必须监听这个具体 ID
tPlot.hangConditionParam = [301010601]
```

### 15.2 事件从触发到剧情播放的完整流程

```text
外部信号
（条件达成、周期、在线时长、餐厅升级、首次进矿层、事件完成、任务生成、引导完成）
        │
        ▼
tEventTrigger.id
  ├─ conditionId：所有触发方式共用的额外解锁门槛
  ├─ eventTriggerType + eventTriggerParam：什么时候尝试触发
  ├─ eventPoolId + eventPoolWeight：先选择一个“事件池标签”
  └─ eventTag → tTagLimit：并发数量限制
        │
        ▼
tEventPool.eventType = 选中的事件池标签
  ├─ resLv：餐厅等级范围
  ├─ filter：该事件类型的历史完成次数范围
  └─ eventTypeId：从若干 tEventGroup.groupId 中抽取一个
        │
        ▼
tEventGroup.groupId = 抽中的 groupId
  ├─ filter + filterParam：筛选具体事件候选
  ├─ Weight：候选权重
  └─ id：最终选中的具体事件 ID
        │
        ▼
按 eventType 读取对应事件详情表并执行事件
        │
        ▼
事件结束，记录 tEventGroup.id 的完成次数
并发送 DurationEventEndEvent.eventGroupEventId
        │
        ▼
tPlot.hangCondition=2
tPlot.hangConditionParam=[tEventGroup.id]
        │
        ▼
tPlotStep → Timeline / tDialogueTable / 奖励 / 任务
        │
        ▼
tDialogContent → tGuideTrole / tlanguage_cn
```

事件结束记录会保存到 `EventData.EventGroupCompleteCounts`。因此剧情既可以在事件结束通知到达时被加入待播放，也可以在之后重新检查时通过历史完成记录判断条件已经满足。真正开始播放时仍要继续满足 `tPlot` 的前置剧情、场景、道具和附加条件。

### 15.3 `tEventTrigger`：事件为什么会开始

| 字段 | 当前代码中的真实作用 |
|---|---|
| `id` | 触发规则 ID。事件运行状态、触发次数和存档以此为键。 |
| `eventPoolId` | 字段名容易误解。它保存的不是 `tEventPool.id`，而是用于匹配 `tEventPool.eventType` 的事件池标签数组。 |
| `eventPoolWeight` | 与 `eventPoolId` 按位置对齐，用权重先选出一个事件池标签。两个数组长度应一致。 |
| `conditionId` | 所有触发类型共用的解锁门槛，指向 `tCommonCondition.id`；不满足时不会继续选池。 |
| `eventTriggerType` | 事件何时尝试启动。当前代码支持 1～8。 |
| `eventTriggerParam` | 与触发类型配套的参数数组。 |
| `logInTrigger` | `1` 表示登录时对尚未触发过的事件补做一次条件检测；`0`/空不检测。 |
| `eventTriggerMax` | 当前刷新周期内的触发次数上限。 |
| `limitResetType` | `1` 永久；`2` 每日；`3` 每周。 |
| `limitResetParam` | 每日/每周刷新时间参数。 |
| `eventTag` | 指向 `tTagLimit.id`，控制相同标签事件的并发数量。 |

当前代码支持的触发类型：

| 类型 | 触发信号 | `eventTriggerParam` |
|---:|---|---|
| 1 | 条件达成 | `[tCommonCondition.id]`；运行时只使用第一项注册条件监听。 |
| 2 | 周期触发 | 触发间隔秒数范围。 |
| 3 | 每日在线时长和时间区间 | `[随机秒数下限,随机秒数上限,小时下限,小时上限]`。 |
| 4 | 餐厅升级 | 可触发的餐厅等级数组。 |
| 5 | 首次进入矿层/关卡 | 可触发的关卡 ID 数组。 |
| 6 | 完成其他事件 | 具体的 `tEventGroup.id` 数组。 |
| 7 | 生成任务 | `tTask.id` 数组。注意是任务生成，不是任务完成。 |
| 8 | 完成引导 | 引导 ID 数组。 |

当前 Excel 表头还写了类型 9“任意食材库存低于特定量”，但当前 `eventTriggerTypeEnum` 没有类型 9，也没有对应监听逻辑；现有正式数据没有使用它。程序实现前不要配置。

`conditionId` 和 `eventTriggerType=1` 不是同一个概念：前者是所有事件都会检查的门槛，后者决定“条件达成这一刻”是否作为启动信号。

### 15.4 `tEventPool`：从一个触发规则中选哪组事件

| 字段 | 当前代码中的真实作用 |
|---|---|
| `id` | 事件池行主键。触发器并不直接引用它；序列选择和分布抽取的运行状态以它为键保存。 |
| `eventType` | 事件池标签，与 `tEventTrigger.eventPoolId` 的元素匹配。它不是 `tEventGroup.eventType` 枚举。 |
| `resLv` | 可使用该池的餐厅等级闭区间 `[下限,上限]`。 |
| `filterType` | Excel 中存在，但当前 `tEventPool.cs` 没有该字段，运行代码不读取。不要依赖它区分筛选分支。 |
| `filter` | 当前代码直接按 `[最低完成次数,最高完成次数]` 检查此 `eventType` 的历史完成次数。 |
| `eventTypeId` | 字段名容易误解。保存的是候选 `tEventGroup.groupId`，不是具体 `tEventGroup.id`。 |
| `randomRule` | `1` 权重随机；`2` 顺序循环；`3` 分布抽取。其他值也会落入权重随机分支。 |
| `eventTypeWeight` | 规则 1：与 groupId 对齐的权重；规则 2：无参数；规则 3：各 groupId 的抽取次数。 |

代码会按表顺序遍历 `tEventPool`，找到第一个同时满足 `eventType`、餐厅等级和完成次数的行后立即返回。相同 `eventType` 下的等级和次数区间不要无意重叠，否则后面的池行可能永远不会被选中。

### 15.5 `tEventGroup`：选出最终具体事件

| 字段 | 当前代码中的真实作用 |
|---|---|
| `id` | 最终具体事件 ID。事件完成通知、完成次数和剧情事件条件都使用它。 |
| `eventType` | 事件业务类型：`1` 流行、`2` 团餐、`3` 特殊顾客、`4` 霸王餐、`5` 挖矿、`6` 食材商人、`7` 家具商人、`8` 对话交互事件。 |
| `groupId` | 被 `tEventPool.eventTypeId` 选中的分组键。多条具体事件可以共用一个 groupId。 |
| `filter` / `filterParam` | 在同一个 groupId 的候选中继续检查食材、菜谱、事件完成次数、属性、道具、矿层等条件。 |
| `Weight` | 对所有通过筛选的具体事件进行最终权重选择。 |
| `endCondition` | `0`/空：挂起事件，由业务系统主动通知完成；`1`：倒计时结束；`2`：倒计时结束或主动放弃。 |
| `endParam` | 类型 1/2 的持续秒数，通常读取第一项。 |
| `eventEndRoleState` | 事件角色结束时切换的状态；空/0 时按业务逻辑销毁。 |

选出 `tEventGroup.id` 后，业务模块通常用同一个 ID 查找事件详情表：

| `tEventGroup.eventType` | 主要事件详情表 | 与对白/文本的关系 |
|---:|---|---|
| 1 流行 | `tTrendContent` | 事件详情和展示文本由流行菜系统配置。 |
| 2 团餐 | `tGroupMeal` | 团餐详情可继续引用角色、奖励和展示配置。 |
| 3/4 特殊顾客/霸王餐 | `tEventCuster` | 结果配置可能继续引用 `tlanguage_cn`、奖励和消耗表。 |
| 5 挖矿 | `tMineEvent` | `tMineEvent.id` 与具体 `tEventGroup.id` 相同；挖矿事件结束后再触发剧情。 |
| 6/7 商人 | `tEventCuster` 及商人模块配置 | 由商人系统读取角色与商品/奖励配置。 |
| 8 对话交互事件 | `tEventGeneralProgress` | `eventTypeParam[0] → tDialogueTable.id`；第二项为 `1` 时，对话结束后完成事件。 |

因此事件表本身通常不直接写 `tDialogueTable` 或 `tlanguage_cn`。只有相应事件详情表需要展示对白时，才继续引用对白组和语言表。事件完成后的正式剧情对白，仍应放在 `tPlotStep → tDialogueTable` 链中。

特别注意类型 8：事件自身可能先播放一组 `tDialogueTable`，对白结束后完成事件；完成事件又可能触发 `tPlot` 播放另一组对白。配置时要明确这两组对白各自承担“事件交互”还是“事件完成后的剧情”，避免重复播放。

### 15.6 `tTagLimit`：事件并发上限

```text
tEventTrigger.eventTag → tTagLimit.id
```

- `eventMaxCount`：同标签当前允许活跃的事件数量。
- `limitHandle=1`：超过上限时排队。
- `limitHandle=2`：超过上限时跳过。

标签计数在事件开始时增加、结束时减少。它控制的是同时活跃数量，不是 `eventTriggerMax` 的历史触发次数；两套限制需要分别配置。

### 15.7 完整案例：事件 `1020` 如何触发剧情 `102004`

```text
首次进入矿层 101020
→ tEventTrigger.id=2020
   eventTriggerType=5
   eventTriggerParam=[101020]
   eventPoolId=[2020]
   eventPoolWeight=[10000]
   eventTriggerMax=1
   limitResetType=1
   eventTag=2000

→ 匹配 tEventPool.eventType=2020
   实际池行 id=20201
   resLv=[1,999]
   eventTypeId=[1020]
   randomRule=1

→ 匹配 tEventGroup.groupId=1020
   最终具体事件 tEventGroup.id=1020
   eventType=5（挖矿事件）
   Weight=10000

→ tMineEvent.id=1020 执行挖矿事件

→ 事件结束发送
   DurationEventEndEvent.eventGroupEventId=1020

→ tPlot.id=102004
   hangCondition=[2]
   hangConditionParam=[1020]

→ 执行剧情步骤
   Timeline 1020
   → 对白组 102040
   → Timeline 10201
   → 奖励 2201010
```

### 15.8 当前 8 条事件触发剧情的对接情况

| 触发器 | 触发方式 | 池行 | `groupId` | 最终 `tEventGroup.id` | 消费剧情 |
|---:|---|---:|---:|---:|---:|
| 2001 | 首次进入关卡 `[100010]` | 20011 | 1001 | 1001 | 101004 |
| 2010 | 首次进入关卡 `[101010]` | 20101 | 1010 | 1010 | 102003 |
| 2020 | 首次进入关卡 `[101020]` | 20201 | 1020 | 1020 | 102004 |
| 2040 | 首次进入关卡 `[101040]` | 20401 | 1040 | 1040 | 102006 |
| 2050 | 首次进入关卡 `[101050]` | 20501 | 1050 | 1050 | 102007 |
| 2070 | 完成事件 `[1050]` | 20701 | 1070 | 1070 | 102014 |
| 3060 | 条件达成 `[230131]` | 30601 | 3010106 | 301010601 | 103008 |
| 2131 | 完成事件 `[1201]` | 21311 | 1301 | 1301 | 103014 |

本次读回中，这 8 个 `tPlot` 事件条件都能找到对应 `tEventGroup.id`，也都能反向找到可选中它的 `tEventPool` 和 `tEventTrigger`，事件到剧情的引用链完整。

### 15.9 配置一条“事件结束后播放剧情”的推荐顺序

1. **配置事件详情表**：根据事件类型新增 `tMineEvent`、`tEventGeneralProgress` 等具体事件数据。
2. **配置 `tEventGroup`**：新增具体 `id`，填写 `eventType`、`groupId`、筛选、权重和结束方式；具体 ID 要与详情表 ID 对齐。
3. **配置 `tEventPool`**：让 `eventTypeId` 包含上一步的 `groupId`，配置等级范围和抽取规则。
4. **配置 `tEventTrigger`**：让 `eventPoolId` 匹配 `tEventPool.eventType`，配置触发信号、参数、次数和事件标签。
5. **配置剧情内容**：按前文顺序配置语言、单句对白、对白组、Timeline、步骤和 `tPlot`。
6. **连接事件和剧情**：在 `tPlot` 填 `hangCondition=[2]`，参数填具体 `tEventGroup.id`。
7. **实机验证两段生命周期**：先确认事件能被选中并正常结束，再确认结束通知携带的具体 ID 能启动目标剧情。

### 15.10 事件与剧情联表 QA

- [ ] `tEventTrigger.eventPoolId` 和 `eventPoolWeight` 长度一致。
- [ ] 每个 `eventPoolId` 元素都能匹配至少一行 `tEventPool.eventType`。
- [ ] 同一 `eventType` 下的 `resLv` 与 `filter` 区间没有非预期重叠。
- [ ] `tEventPool.eventTypeId` 和规则 1/3 的参数长度匹配。
- [ ] 每个 `eventTypeId` 元素都能匹配至少一条 `tEventGroup.groupId`。
- [ ] 每个具体 `tEventGroup.id` 在对应事件详情表中存在。
- [ ] `tPlot.hangConditionParam` 使用具体 `tEventGroup.id`，没有误用 groupId、Trigger ID 或 Pool ID。
- [ ] 事件结束方式确实会走完成流程并发送 `DurationEventEndEvent`。
- [ ] 事件完成时场景与 `tPlot.plotScene` 的设计一致，或接受剧情稍后在目标场景播放。
- [ ] 事件内对白和事件完成后剧情对白没有重复或顺序冲突。
- [ ] 公式重新计算后，所有数组缓存值仍可读，且无公式错误。

当前源表还有一个与上述 8 条剧情链无关、但应修复的历史风险：`tEventTrigger` 第 11 行和第 55 行重复使用 ID `106`，两行备注都是“测试用_商人-食材_测试1”，但周期参数分别为 `[400,600]` 和 `[280,320]`。导出后可能发生后行覆盖前行，新增配置前不应继续复用该 ID。

事件工作簿当前公式读回结果为：`tEventTrigger` 1 个公式单元格、`tEventPool` 29 个、`tEventGroup` 117 个；本次未发现空缓存或 `#REF!/#DIV/0!/#VALUE!/#NAME?`。但只要修改了公式依赖行，仍必须重新计算并再次读回。
