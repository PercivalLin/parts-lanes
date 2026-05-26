<div align="center">

<img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License">
<img src="https://img.shields.io/badge/python-3.9%2B-green.svg" alt="Python">
<img src="https://img.shields.io/badge/依赖-零-brightgreen.svg" alt="Dependencies">

<h1>Parts Lanes</h1>

[English](README.md) | [中文](README.zh-CN.md)

> AI 编程 agent 的并行开发车道协议。

</div>

**Parts Lanes** 解决一个问题：多个 AI agent 在同一个仓库里改代码时，互相不知道对方在改什么，最后 merge 时才发现冲突。

Worktree 隔离了文件目录，Parts Lanes 隔离了工作内容。每个 AI 线程必须先进入自己的 Lane，声明任务，claim 代码路径，然后才能开始改。如果有别的 Lane 已经 claim 了同一片代码，冲突在**动手之前**就会被发现。

<p align="center"><b>Worktree 防文件覆盖，Parts Lanes 防工作撞车。</b></p>

---

## 这是什么

Parts Lanes 是一个 **Codex Agent Skill**，附带一个 CLI 工具。它以单个目录（`.agents/skills/parts-lanes/`）的形式存在，放入任何 Git 仓库即可生效。安装后，Codex agent 会自动加载 skill 并遵守车道协议。`parts-lane` CLI 则在终端执行规则。

可以把它理解为"一套约定 + 一个脚本"，而不是需要注册的平台。

## 安装

```bash
# 安装到当前仓库
curl -fsSL https://raw.githubusercontent.com/PercivalLin/parts-lanes/main/install.sh | bash

# 或者指定目标目录
curl -fsSL https://raw.githubusercontent.com/PercivalLin/parts-lanes/main/install.sh | bash -s /path/to/你的项目
```

不指定目标目录时，安装器会使用最近的 Git 仓库根目录，所以在项目子目录里运行也可以。

安装器会下载零依赖的 `parts-lane` CLI，初始化仓库内 Codex skill、AGENTS 指令、
hooks、配置和本地 `./parts-lane` 命令，并且默认不覆盖项目里已有的文件。想先预览：

```bash
curl -fsSL https://raw.githubusercontent.com/PercivalLin/parts-lanes/main/install.sh | bash -s -- --dry-run /path/to/你的项目
```

## 快速开始

```bash
# 1. 检查安装状态
./parts-lane doctor

# 2. 开一个新的 worktree Lane
./parts-lane begin --worktree

# 3. 告诉它你要做什么
./parts-lane task set "给登录加限流"

# 4. 声明你要改的代码
./parts-lane claim "src/auth/**" "tests/auth/**"

# 5. 改完代码后同步
./parts-lane sync

# 6. 完成前过闸检查
./parts-lane check
./parts-lane ready
```

就这样。你的 agent 现在有了身份、声明了代码占用、有了可验证的完成状态。

---

## 解决了什么问题

你在同一个项目里开了三个 Codex 线程：

```
线程 A → 重写了 src/auth/login.ts
线程 B → 也重写了 src/auth/login.ts
线程 C → 改了 src/auth/session.ts（A 也改了）
```

Git 会在 merge 时发现文件级冲突。但到那时候两边都已经干完活了。更糟的是，改的时候谁都不知道对方存在。

## Parts Lanes 怎么解决

在 Git 之上加了一层轻量协议：

```
线程 A → claim "src/auth/**" → 通过 → 改代码 → sync → ready
线程 B → claim "src/auth/session.ts" → 被拒（Lane A 已持有 src/auth/**）
```

线程 B **在一行代码都没写的时候**就被拦住了。没有浪费的工作，没有 merge 时的惊吓。

---

## 原理

```
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│   Agent A    │    │   Agent B    │    │   Agent C    │
│   Lane L-001 │    │   Lane L-002 │    │   Lane L-003 │
└──────┬───────┘    └──────┬───────┘    └──────┬───────┘
       │ claim             │ claim             │ claim
       ▼                   ▼                   ▼
┌──────────────────────────────────────────────────────┐
│                   声明引擎                           │
│  src/auth/**  ✓               src/auth/session.ts ✗ │
└──────────────────────────────────────────────────────┘
       │                                           │
       ▼                                           ▼
   自由改动代码                              报告冲突，停止工作
       │
       ▼
┌──────────────────────────────────────────────────────┐
│               Gate → Check → Ready                   │
│  • 声明有冲突吗？           • 测试过了吗？            │
│  • 改动在声明范围内吗？     • Lint 过了吗？           │
│  • 改了受保护的分支/路径？  • 是最新 diff 的结果吗？  │
└──────────────────────────────────────────────────────┘
```

### 核心概念

| 概念 | 含义 |
|------|------|
| **Lane（车道）** | 一个 AI 线程的运行时身份——谁、在干什么、占了哪些代码 |
| **Claim（声明）** | 动手前声明的 glob 路径（如 `src/auth/**`）。两个 Lane 不能持有重叠的声明 |
| **Gate（闸门）** | 确定性检查：有无声明冲突、是否越界改代码、是否触碰受保护路径 |
| **Ready（就绪）** | 所有 Gate 通过 + 所有配置的检查命令在当前 diff 上执行通过 |

### Lane 识别机制

当 agent 运行 `parts-lane current` 时，脚本通过三层策略识别当前 Lane：

1. **Codex hook 身份** — 从 hook JSON 中匹配 `session_id` + `agent_id`
2. **Git 工作区** — 匹配当前分支名或 worktree 路径
3. **本地回退** — `.git/parts/current_lane_by_cwd.json`

---

## 命令

| 命令 | 说明 |
|------|------|
| `init [--dry-run] [--force]` | 在仓库中初始化 Parts Lanes |
| `begin [--worktree]` | 创建或接入一个 Lane |
| `current [--json]` | 识别当前 Lane |
| `doctor` | 诊断安装、hooks、worktree 和 Lane 状态 |
| `task set <摘要>` | 设置 Lane 的任务 |
| `task update <摘要>` | 修改任务（递增修订计数） |
| `claim <pattern> ...` | 修改代码前声明文件路径 |
| `claim-add <pattern> ...` | 追加声明路径 |
| `sync [--soft]` | 读取 git diff 并记录实际改动 |
| `gate [--soft]` | 运行冲突和安全检查 |
| `check [--name]` | 执行配置的测试/lint/类型检查命令 |
| `ready [--json]` | 判断 Lane 是否可以安全完成 |
| `status [--json]` | 查看所有活跃 Lane 及其状态 |
| `close [lane_id]` | 关闭一个 Lane |
| `hook <event>` | 处理 Codex 生命周期事件（由 hook 自动调用） |

---

## 配置

编辑 `.parts/config.yaml` 适配你的项目：

```yaml
protected_branches:        # 在这些分支上提交会触发 gate 失败
  - main
  - master
  - release/*

protected_paths:           # 修改这些路径触发 gate 失败
  - .github/workflows/**
  - infra/**
  - .env

high_risk_paths:           # 修改这些路径触发警告
  - package-lock.json
  - migrations/**

checks:                    # parts-lane check 可执行的命令
  default:
    # - name: test
    #   command: npm test
    # - name: lint
    #   command: npm run lint

ready:                     # 全部通过才算 ready
  require:
    - task_set
    - no_claim_conflict
    - actual_changes_within_claim
    - no_actual_file_overlap
    - checks_after_latest_diff
```

---

## 状态存储

所有 Lane 状态存储在 `.git/parts/state.sqlite`（不提交到 Git）：

```
lanes            — id, state, task_summary, task_revision, branch, worktree
claims           — lane_id, glob 模式
observed_files   — lane_id, 文件路径, diff_hash
checks           — lane_id, 命令, exit_code, status, diff_hash
events           — lane_id, 事件类型, JSON payload
thread_bindings  — session_id, agent_id → lane_id
```

检查结果绑定到 **diff hash**。如果测试通过后又改了代码，旧的检查结果就失效了。Agent 不能跳过重新检查就声称完成。

---

## 在 Codex 中使用

### 安装

`./parts-lane init` 会写入或合并这些文件：

```
repo/
  parts-lane                          ← 本地命令入口
  AGENTS.md                          ← Codex 启动时读取
  .agents/skills/parts-lanes/
    SKILL.md                         ← Agent skill 定义
    scripts/parts-lane               ← CLI（零依赖）
    references/lane-protocol.md      ← 协议参考
  .parts/config.yaml                 ← 项目配置
  .codex/hooks.json                  ← 生命周期 hook 注册
```

### Worktree 线程（推荐）

在 Codex 中为同一个项目开多个 Worktree 线程。每个线程通过 `SessionStart` hook 自动获得自己的 Lane。路径声明会阻止跨线程冲突。

### CLI 多窗口

```bash
codex --cd .parts/worktrees/L-001   # 线程 A
codex --cd .parts/worktrees/L-002   # 线程 B
```

`parts-lane current` 通过工作目录识别每个线程。

---

## 设计原则

- **Lane 先于任务。** 线程先有 Lane，任务由用户后续指定。
- **AI 不直接编辑状态。** 所有状态变更必须通过 `parts-lane` 脚本。
- **任务可以改，但代码占用不能自动扩大。** 改任务不等于能改新文件，必须另行 `claim-add`。
- **检查结果绑定 diff。** 测试通过只对当时的 diff 有效。
- **协议是协作式的，不是沙箱。** Hook 负责提醒，Gate/Ready 负责卡关。

---

## 环境要求

- Python 3.9+
- Git
- 零外部依赖（仅使用标准库：`sqlite3`、`argparse`、`subprocess`、`hashlib`、`fnmatch`、`json`）

---

## 许可证

[MIT](LICENSE)
