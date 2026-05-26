<p align="center">
  <img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License">
  <img src="https://img.shields.io/badge/python-3.9%2B-green.svg" alt="Python">
  <img src="https://img.shields.io/badge/dependencies-zero-brightgreen.svg" alt="Dependencies">
</p>

# Parts Lanes

> A parallel development lane protocol for AI coding agents.

**Parts Lanes** prevents multiple AI agents from editing the same files in the same repository. Before touching any code, each agent must enter a Lane, declare its task, and claim the file paths it intends to modify. If another agent already holds a conflicting claim, the collision is caught *before editing* — not during merge.

<p align="center"><b>Worktree isolates files. Parts Lanes isolates work.</b></p>

---

## Quick Start

```bash
# 1. Initialize Parts Lanes in your repo
parts-lane init

# 2. Start a new Lane
parts-lane begin

# 3. Tell it what you're doing
parts-lane task set "Add rate limiting to login"

# 4. Claim the code you need
parts-lane claim "src/auth/**" "tests/auth/**"

# 5. Edit files, then sync
parts-lane sync

# 6. Run checks before wrapping up
parts-lane check
parts-lane ready
```

That's it. Your agent now has a lane identity, declared claims, and verifiable completion status.

---

## The Problem

You open three Codex threads on the same repo:

```
Thread A → rewrites src/auth/login.ts
Thread B → also rewrites src/auth/login.ts
Thread C → touches src/auth/session.ts (which A also changed)
```

Git will catch the file-level conflict at merge time. But by then both agents have already done the work. Worse, neither agent knew the other existed.

## The Solution

Parts Lanes adds a lightweight protocol on top of git:

```
Thread A → claim "src/auth/**" → accepted → edits files → sync → ready
Thread B → claim "src/auth/session.ts" → REJECTED (Lane A holds src/auth/**)
```

Thread B is blocked **before writing a single line**. No wasted work, no merge surprises.

---

## How It Works

```
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│   Agent A    │    │   Agent B    │    │   Agent C    │
│   Lane L-001 │    │   Lane L-002 │    │   Lane L-003 │
└──────┬───────┘    └──────┬───────┘    └──────┬───────┘
       │ claim             │ claim             │ claim
       ▼                   ▼                   ▼
┌──────────────────────────────────────────────────────┐
│                   Claim Engine                       │
│  src/auth/**  ✓               src/auth/session.ts ✗ │
└──────────────────────────────────────────────────────┘
       │                                           │
       ▼                                           ▼
   Edit freely                             Conflict reported
       │
       ▼
┌──────────────────────────────────────────────────────┐
│               Gate → Check → Ready                   │
│  • No claim overlap?        • Tests pass?            │
│  • Changes within claims?   • Lint passes?           │
│  • Not on protected branch? • Checks for this diff?  │
└──────────────────────────────────────────────────────┘
```

### Core Concepts

| Concept | Meaning |
|---------|---------|
| **Lane** | A runtime identity for one AI thread — who it is, what it's doing, what code it owns |
| **Claim** | A glob pattern (`src/auth/**`) declared before editing. Two lanes cannot hold overlapping claims. |
| **Gate** | Deterministic checks: no claim conflicts, no protected-path edits, no out-of-claim changes |
| **Ready** | All gates pass + all configured checks pass against the current diff |

### Lane Identification

When an agent runs `parts-lane current`, the script identifies the lane through three tiers:

1. **Codex hook identity** — matches `session_id` + `agent_id` from hook JSON
2. **Git workspace** — matches current branch or worktree path
3. **Local fallback** — `.git/parts/current_lane_by_cwd.json`

---

## Commands

| Command | Description |
|---------|-------------|
| `init` | Initialize Parts Lanes in a repository |
| `begin [--worktree]` | Create or attach to a lane |
| `current [--json]` | Identify the current lane |
| `task set <summary>` | Set the lane's task description |
| `task update <summary>` | Change the task (increments revision counter) |
| `claim <pattern> ...` | Claim file paths before editing |
| `claim-add <pattern> ...` | Add more claims to the current lane |
| `sync [--soft]` | Read git diff and record observed state |
| `gate [--soft]` | Run collision and safety checks |
| `check [--name]` | Execute configured test/lint/typecheck commands |
| `ready [--json]` | Determine if the lane is safe to complete |
| `status [--json]` | Show all active lanes and their states |
| `close [lane_id]` | Close a lane |
| `hook <event>` | Handle Codex lifecycle events (called by hooks, not directly) |

---

## Configuration

Edit `.parts/config.yaml` to match your project:

```yaml
protected_branches:        # Commits on these branches will fail gate
  - main
  - master
  - release/*

protected_paths:           # Editing these paths fails gate
  - .github/workflows/**
  - infra/**
  - .env

high_risk_paths:           # Editing these triggers a warning
  - package-lock.json
  - migrations/**

checks:                    # Commands run by `parts-lane check`
  default:
    - name: test
      command: npm test
    - name: lint
      command: npm run lint

ready:                     # All must pass for `ready` to return yes
  require:
    - task_set
    - no_claim_conflict
    - actual_changes_within_claim
    - no_actual_file_overlap
    - checks_after_latest_diff
```

---

## State Storage

All lane state lives in `.git/parts/state.sqlite` (not committed):

```
lanes            — id, state, task_summary, task_revision, branch, worktree
claims           — lane_id, glob pattern
observed_files   — lane_id, file path, diff_hash
checks           — lane_id, command, exit_code, status, diff_hash
events           — lane_id, event type, JSON payload
thread_bindings  — session_id, agent_id → lane_id
```

Check results are bound to a **diff hash**. If code changes after tests pass, the old check results are invalidated. The agent cannot claim completion without re-running checks against the current diff.

---

## Using with Codex

### Setup

`parts-lane init` writes these files:

```
repo/
  AGENTS.md                          ← Codex reads this on startup
  .agents/skills/parts-lanes/
    SKILL.md                         ← Agent skill definition
    scripts/parts-lane               ← The CLI (zero dependencies)
    references/lane-protocol.md      ← Protocol reference
  .parts/config.yaml                 ← Your project configuration
  .codex/hooks.json                  ← Lifecycle hook registrations
```

### Worktree Threads (Recommended)

Open multiple Codex worktree threads on the same project. Each thread gets its own Lane automatically via the `SessionStart` hook. Path claims prevent collisions across threads.

### CLI Threads

```bash
codex --cd .parts/worktrees/L-001   # Thread A
codex --cd .parts/worktrees/L-002   # Thread B
```

`parts-lane current` identifies each thread by its working directory.

---

## Design Principles

- **Lane before task.** A thread gets a Lane first. The task is set later, when the user gives instructions.
- **AI never edits state directly.** All state changes go through the `parts-lane` script.
- **Task can change, claims cannot auto-expand.** Changing the task does not grant new file access. The agent must call `claim-add`.
- **Checks are bound to diffs.** A passing test result is only valid for the exact diff it was run against.
- **The protocol is cooperative, not a sandbox.** Hooks inform and remind. Enforcement is in the gate/ready commands.

---

## Requirements

- Python 3.9+
- Git
- Zero external dependencies (stdlib only: `sqlite3`, `argparse`, `subprocess`, `hashlib`, `fnmatch`, `json`)

---

## License

[MIT](LICENSE)
