# 分诊标签

skill 以五个标准分诊角色表达。本文件把角色映射到本仓库实际使用的标签字符串。

| skill 中的角色 | 本仓库的标签 | 含义 |
| --- | --- | --- |
| `needs-triage` | `needs-triage` | 维护者需要评估该问题 |
| `needs-info` | `needs-info` | 等待报告者补充信息 |
| `ready-for-agent` | `ready-for-agent` | 已完整规格化，可交给 AFK agent |
| `ready-for-human` | `ready-for-human` | 需要人工实现 |
| `wontfix` | `wontfix` | 不予处理 |

当 skill 提到某个角色（如"打上 AFK-ready 分诊标签"）时，使用表中对应的标签字符串。
