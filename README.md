# bubble-story-event-guide-config

Bubble 项目的独立剧情、事件与新手引导配置 Skill。它把自然语言需求接入活动需求池，依据当前项目规则、配置表、代码和 Prefab 生成可审查的配置草案，并执行 ID、引用、JSON、触发链、`END` 下方写入边界、回读和 QA 流程。

## 安装

将本仓库目录复制到项目的：

```text
.agents/skills/bubble-story-event-guide-config/
```

或复制到个人 Codex Skills 目录，并保持目录名不变。

## 项目侧初始化

首次部署到 Bubble 项目时，必须把 skill 内的两个模板复制到项目活动需求池路径：

```text
assets/templates/剧情事件需求池模板.xlsx
→ 策划/配置表/剧情、事件AI配置/剧情事件需求池.xlsx

assets/templates/新手引导需求填写模板.xlsx
→ 策划/配置表/新手引导AI配置/新手引导需求池.xlsx
```

如果目标文件已经存在，直接沿用，不要覆盖团队已有需求和处理状态。

## 使用

```text
用 $bubble-story-event-guide-config 处理剧情事件需求池。
用 $bubble-story-event-guide-config 处理新手引导需求池。
用 $bubble-story-event-guide-config 处理所有待配置内容。
```

具体路径、角色分工、审核顺序和复制说明见 `references/team-usage.md`；领域规则见 `references/story-event/` 与 `references/guide/`。

本 Skill 独立于 `bubble-config-table-generator`，不会修改或合并该 Skill。
