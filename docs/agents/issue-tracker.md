# 问题跟踪：GitHub

本仓库的问题与规格记录在 GitHub Issues 中。所有操作使用 `gh` CLI。

## 约定

- **创建 issue**：`gh issue create --title "..." --body "..."`。多行正文用 heredoc。
- **读取 issue**：`gh issue view <number> --comments`，用 `jq` 过滤评论并一并取出 labels。
- **列出 issue**：`gh issue list --state open --json number,title,body,labels,comments --jq '[.[] | {number, title, body, labels: [.labels[].name], comments: [.comments[].body]}]'`，配合 `--label` 与 `--state` 过滤。
- **评论 issue**：`gh issue comment <number> --body "..."`
- **增删标签**：`gh issue edit <number> --add-label "..."` / `--remove-label "..."`
- **关闭**：`gh issue close <number> --comment "..."`

仓库由 `git remote -v` 推断；在克隆目录内运行 `gh` 时会自动识别。

## Pull Request 作为分诊面

**PR 作为请求入口：否。** _（若本仓库把外部 PR 当作功能请求，改为 `yes`；`/triage` 会读这个开关。）_

设为 `yes` 时，PR 与 issue 走同一套标签与状态机，使用对应的 `gh pr` 命令：

- **读取 PR**：`gh pr view <number> --comments`，diff 用 `gh pr diff <number>`。
- **列出待分诊的外部 PR**：`gh pr list --state open --json number,title,body,labels,author,authorAssociation,comments`，只保留 `authorAssociation` 为 `CONTRIBUTOR`、`FIRST_TIME_CONTRIBUTOR`、`NONE` 的（丢弃 `OWNER`/`MEMBER`/`COLLABORATOR`）。
- **评论 / 打标签 / 关闭**：`gh pr comment`、`gh pr edit --add-label`/`--remove-label`、`gh pr close`。

GitHub 的 issue 与 PR 共用同一套编号，因此裸 `#42` 可能是两者之一：先用 `gh pr view 42` 解析，回退到 `gh issue view 42`。

## 当 skill 说"发布到问题跟踪器"

创建一个 GitHub issue。

## 当 skill 说"取出相关工单"

运行 `gh issue view <number> --comments`。

## 寻路（Wayfinding）操作

由 `/wayfinder` 使用。**地图（map）** 是一个 issue，**子 issue** 作为工单。

- **地图**：一个带 `wayfinder:map` 标签的 issue，承载 Notes / Decisions-so-far / Fog 正文。`gh issue create --label wayfinder:map`。
- **子工单**：通过 GitHub 子 issue 关联到地图的 issue（用 `gh api` 调 sub-issues 端点）。在不支持子 issue 的地方，把子工单加入地图正文的任务列表，并在子工单正文顶部写 `Part of #<map>`。标签：`wayfinder:<type>`（`research`/`prototype`/`grilling`/`task`）。被认领后指派给执行者。
- **阻塞**：使用 GitHub 原生的 issue 依赖关系，这是规范且界面可见的表示。用 `gh api --method POST repos/<owner>/<repo>/issues/<child>/dependencies/blocked_by -F issue_id=<blocker-db-id>` 添加边，其中 `<blocker-db-id>` 是阻塞者的数字**数据库 id**（`gh api repos/<owner>/<repo>/issues/<n> --jq .id`，**不是** `#number` 或 `node_id`）。GitHub 报告 `issue_dependencies_summary.blocked_by`（仅未关闭的阻塞者，即实时闸门）。在不支持依赖关系的地方，回退为子工单正文顶部的 `Blocked by: #<n>, #<n>` 行。所有阻塞者关闭后，工单即解除阻塞。
- **前沿（Frontier）查询**：列出地图的未关闭子工单（`gh issue list --state open`，限定为地图的子 issue / 任务列表），丢弃有未关闭阻塞者（`issue_dependencies_summary.blocked_by > 0`，或 `Blocked by` 行中有未关闭 issue）或已有指派者的，按地图顺序取第一个。
- **认领**：`gh issue edit <n> --add-assignee @me`，这是本会话的第一次写操作。
- **解决**：`gh issue comment <n> --body "<答案>"`，然后 `gh issue close <n>`，再把上下文指针（要点 + 链接）追加到地图的 Decisions-so-far。
