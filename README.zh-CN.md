# AiEconLab

[English README](README.md)

AiEconLab，简称 AEL，是给经济学论文项目用的一支 AI 研究团队。

它不是让一个聊天窗口同时扮演 Advisor、PI、RA、理论作者、审稿人和复现者。
AEL 把这些职责拆开：你需要判断研究方向时找 Advisor，需要推进任务时找 PI，
需要跑回归时找 RA，需要挑错时找 Referee。

AEL 适合用来：

- 想清楚一个研究想法值不值得做
- 反思识别策略是否可信
- 规划数据清洗、合并、回归和稳健性检验
- 在论文写得太满之前先找人挑刺
- 检查结果能不能复现
- 管理一篇论文接下来的任务

## 从这里开始

1. 先装一个支持的 AI coding runtime：
   [Claude Code](https://code.claude.com/docs/en/getting-started)、
   [Codex](https://developers.openai.com/codex/cli) 或
   [OpenCode](https://opencode.ai/docs/)。先单独打开它，确认能正常聊天。
2. 用下面的命令安装 AEL。
3. 进入你的论文、复现或数据项目文件夹，运行 `ael`。
4. 选择你要找谁：PI、Advisor、RA-Stata、RA-Python、Referee，或其他角色。

最快开始：

```bash
curl -fsSL https://raw.githubusercontent.com/izhiwen/AiEconLab/main/install.sh | bash
cd MyPaperProject
ael
```

Windows PowerShell：

```powershell
irm https://raw.githubusercontent.com/izhiwen/AiEconLab/main/install.ps1 | iex
cd MyPaperProject
ael install
ael
```

Windows 支持目前只经过 CI 验证。如果你在使用 PowerShell 快速安装时遇到问题，请到 https://github.com/izhiwen/AiEconLab/issues 提 issue，我们想听到反馈。

macOS/Linux 上，第一次在项目里运行 `ael` 时会自动设置项目。Windows 上请先在
项目里运行一次 `ael install`，再运行 `ael`。

如果安装器提示命令不在 `PATH`，照它打印出来的一行命令修一下，然后重新打开终端。

## 你会输入什么

打开大厅：

```bash
ael
```

找 PI，让它帮你拆任务、派工、汇总：

```bash
ael pi
```

找 Advisor，做战略判断和第二意见：

```bash
ael advisor
```

任务已经很明确时，直接找具体角色：

```bash
ael ra-stata
ael ra-python
ael theorist
ael referee
ael replicator
ael pm
```

不想接着上次聊，想开一个新会话：

```bash
ael advisor --fresh
```

检查或修复项目设置：

```bash
ael status
ael doctor
ael doctor --fix
```

更新后刷新 AEL 管理的项目文件：

```bash
ael refresh --dry-run
ael refresh
```

## 我该找哪个角色？

找 **Advisor**，当你想要判断：

- 这个题目值不值得做？
- 这个识别策略站不站得住？
- 这个项目现实里应该做到多大野心？
- 审稿人最容易攻击哪里？

找 **PI**，当你想要推进：

- 把这个想法拆成任务。
- 决定谁来做什么。
- 看现在有哪些事在进行。
- 把 Advisor 的意见变成下一步工作。

找 **RA-Stata**：回归、表格、Stata、稳健性检验。

找 **RA-Python**：数据清洗、合并、抓取、GIS、文本处理、Python 管线。

找 **Theorist**：识别假设、机制、模型、工具变量、解释。

找 **Referee**：在你相信一个 claim 之前，让它像审稿人一样挑刺。

找 **Replicator**：在数字离开项目之前，检查能不能从干净环境复现。

找 **PM**：deadline、阻塞项、里程碑、项目节奏。

## 常见用法

早期想法：

```text
ael advisor
"我想做一个关于 X 的论文。最大的三个设计风险是什么？"
```

把判断变成任务：

```text
ael pi
"Advisor 觉得最大风险是样本选择。请规划下一步验证。"
```

对外展示前先挨打：

```text
ael referee
"用最苛刻审稿人的角度读一下这个摘要，告诉我最容易被拒的理由。"
```

相信一张表之前：

```text
ael replicator
"检查主表能不能从干净 checkout 复现。"
```

## AEL 到底加了什么

AEL 给 AI 辅助研究加的是团队结构和研究纪律：

- 每个角色有自己的 persona
- 项目本地记忆
- 团队共享记忆
- 不同角色有清楚的工作边界
- 面向经济学的专家角色
- 为中等和重任务准备的研究版 consultant team
- 需要 Owner 决定的 STOP-gates

它不是说 AI 可以自己做完一篇论文。人类研究者仍然是 Owner。AEL 的作用是让 AI
帮忙时不乱串角色、不乱夸结果、不忘项目上下文。

## Consultant Team

AEL 有自己的 consultant team，不是默认的软件工程 consultant team。

AEL 的 consultant team 是为经济学研究准备的：

- 识别策略可信度
- 论文贡献和定位
- 从第一天开始的复现要求
- IRB 和披露风险
- LLM-as-measurement 的测量有效性

小任务会跳过 consultant。中等和重任务可以先触发 consultant，再派给具体角色做。

## LLM-as-Measurement

AEL 内置 LLM-as-measurement 专家，适合用大模型给档案文本、开放式回答、
历史文献或其他非结构化材料打分的论文。

这个角色关注：多模型一致性、人工标注验证、评分稳定性、prompt 版本管理，
以及测量误差会不会影响实证结论。

示例项目：
[Multi-LLM-Validation-Demo](https://github.com/izhiwen/Multi-LLM-Validation-Demo)。

![两两 LLM 相关性热力图](https://raw.githubusercontent.com/izhiwen/Multi-LLM-Validation-Demo/main/figures/multi_llm_correlation_heatmap.png)

## 安全边界

AEL 留在你的本地项目里。它不会：

- 上传项目文件、记忆或对话记录
- 作为后台守护进程运行
- 在角色设定里保存受限数据路径或密钥
- 修改无关项目
- 自动批准投稿、公开 working paper、发送 referee response、共享数据、改变作者顺序等 Owner-gated actions

角色可以帮你准备材料，但外部、敏感、不可逆的动作仍然由人类 Owner 决定。

## 演示

v1.0.0 readiness 的 Lane B 发布托管终端录屏后，会在这里补上链接。

## 出问题时

检查项目：

```bash
ael doctor
```

让 AEL 修复常见本地漂移：

```bash
ael doctor --fix
```

预览更新：

```bash
ael update --dry-run
```

只删除安装好的命令，保留项目文件：

```bash
ael uninstall --yes
```

删除安装好的命令，也删除当前项目里的 AEL 状态：

```bash
ael uninstall --purge --yes
```

## 维护者

构建 release package：

```bash
git submodule update --init --recursive
scripts/build-ael.sh --package
```

release workflow 会发布平台 tarball 和 SHA256 sidecar，供安装器使用。

## 高级说明

AEL 构建在 AiPlus agent substrate 之上；对外支持的入口只有 `ael` CLI 和本仓库。

## 许可证

Apache-2.0。见 [LICENSE](LICENSE)。
