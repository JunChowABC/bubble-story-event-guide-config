---
name: bubble-story-event-guide-config
description: Configure Bubble project stories, dialogues, events, and new-player tutorials through the team's request pools, END-below draft workflow, project evidence, ID allocation, cross-table linking, and QA. Use for 剧情、事件、事件内对话、新手引导、需求池待配置 or related work under the two AI configuration directories; do not use for unrelated Bubble configuration tables.
metadata:
  author: Bubble project
  version: "1.1.1"
---

# Bubble 剧情、事件与新手引导配置

把团队的自然语言需求转换为可审查的 Bubble 配置草案。这个 Skill 是独立工作流，不依赖也不修改 `bubble-config-table-generator`。

## 每次任务先做

1. 完整读取 [references/unified-workflow.md](references/unified-workflow.md)。
2. 在 Bubble 项目内运行 `scripts/check_source_drift.ps1 -ProjectRoot <项目根目录>`。若结果为 `drift`，优先读取项目中的最新原文并在交付中说明 Skill 快照已过期；不要静默按旧快照配表。
3. 根据任务路由读取下列原始规则快照：
   - 剧情、对白、事件或剧情与事件连接：先完整读取 [剧情事件工作流](references/story-event/剧情事件AI配置工作流.md)。
   - 剧情、对白或剧情与事件连接：再完整读取 [剧情配置说明](references/story-event/剧情配置说明_给AI使用.md)。
   - 事件、事件内对话或事件详情：再完整读取 [事件配置说明](references/story-event/事件配置说明_给AI使用.md)。若事件还会播放正式剧情，同时读取剧情说明。
   - 新手引导：完整读取 [新手引导工作流](references/guide/新手引导AI配置工作流.md) 和 [新手引导配置说明](references/guide/新手引导配置说明_给AI使用.md)。需要复用或核对现有组链时，再读 [现有链路索引](references/guide/新手引导配置说明_附录_现有链路索引.md)；需要核对旧备忘、截图或历史锚点时，才读 [原表备忘页](references/guide/新手引导配置说明_附录_原表备忘页.md)。
4. 编辑工作簿前，读取当前目标工作簿、当前运行时代码、相关 Prefab 和关联表。表头或快照与当前代码冲突时，以当前代码行为为准并记录差异。

## 入口与路由

- “处理剧情事件需求池”“处理剧情配置需求池”或“处理剧情/事件待配置”：读取 `策划/配置表/剧情、事件AI配置/剧情事件需求池.xlsx` 的 `填写需求` 页。旧 `剧情事件AI输入模板/` 只作兼容资料，不作为默认接单入口。
- “处理新手引导需求池”：读取 `策划/配置表/新手引导AI配置/新手引导需求池.xlsx`。
- “处理所有待配置”：分别筛选两个活动池；先建立跨域依赖，再按拓扑顺序处理，不按文件夹顺序硬排。
- 用户直接给自然语言需求时，按 `纯剧情/独立对白/事件内对话/事件/新手引导/跨域链` 分类；不确定项可生成 `A-假设` 草案，但高风险 ID、枚举、路径、触发和存档行为不得冒充已验证值。

活动需求池是当前状态的唯一事实源。`assets/templates/` 只用于新成员或新项目复制，不能覆盖已有活动池。

## 不可破坏的边界

- `策划/配置表/Table` 是只读正式源；只在本次输出目录的工作簿副本中修改。
- 默认把新增或修改行写在每个目标 Sheet 的 A 列首个严格等于 `END` 的行下方；不移动、不覆盖、不新增第二个 `END`。
- 未经用户明确授权“激活/写入正式区”，不得把草案移到 `END` 上方，也不得宣称已经导表或游戏内生效。
- 保留 6 行协议头、Sheet 名、字段拼写、样式、公式、图片、隐藏状态和数据验证。数组与代码解析的复合字符串必须是严格 JSON。
- 玩家可见文字进入 `tlanguage_cn`；业务表只引用语言 ID。
- ID 在正确作用域内按现有业务段和父子前缀分配；先列候选、查冲突，再写表。禁止把 Trigger ID、Pool 行 ID、groupId 和具体 Event ID 混用。
- 现有源文件中的历史异常只记录风险；除非本次需求直接涉及或用户授权，不扩大修改范围。

## 固定执行合同

1. 筛选有效待配置行并锁定为“配置中”。若无法安全继续，把状态恢复为“待配置”并写明需要确认的原因。
2. 建立 S/T/D/A 证据包、工作簿归属计划、ID 台账和完整触发结论。
3. 先生成叶子数据和依赖，再串顶层入口；跨域链按 [统一工作流](references/unified-workflow.md) 的依赖顺序执行。
4. 在输出副本的 `END` 下方生成草案；修改正式行时，把原行完整复制到草案区再提出修改。
5. 保存后重新打开所有工作簿，做结构、JSON、公式、ID、外键、文本、触发、存档/中断和视觉 QA。可用时执行项目导表器；没有实机验证时明确写“仅静态可用”。
6. 成功后回填活动池的表、ID、输出路径、假设、待确认项和完成时间，并更新为“已完成”。
7. 交付工作簿、`generation-manifest.json`、配置记录、预览或渲染证据、QA 结果、测试步骤和成熟度。不要只交付文字分析。

## 团队复用

团队成员的安装、两个需求池模板的复制路径、最短指令和职责分工见 [references/team-usage.md](references/team-usage.md)。首次部署到项目时，必须把剧情事件和新手引导两个模板分别复制到说明指定的活动需求池路径；目标文件已存在时不得覆盖。
