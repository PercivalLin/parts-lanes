# Parts Lanes Protocol Reference

## Lane Concept

A Lane is a runtime state object that represents one AI coding thread's identity, task, and code claims. Each Codex thread or worktree session gets its own Lane.

## Lane Lifecycle

```
idle → active → closed
```

- **idle**: Lane exists but has no task. Waiting for user instructions.
- **active**: Lane has a task set. Agent is working on it.
- **closed**: Lane is complete. No further edits.

## Claim-Before-Edit Contract

Before editing any file, the agent must claim the path pattern (e.g., `src/auth/**`). The claim system prevents two lanes from editing overlapping code.

Claim validation rules:
- Patterns must contain at least one concrete directory segment before any glob wildcard
- `src/**` is too broad and will be rejected
- `src/auth/**` is valid (2 concrete segments before `**`)
- `src/auth/login.ts` is valid (exact file)

## Gate / Check / Ready Pipeline

### Gate (deterministic checks)
- Not on a protected branch
- No claim conflicts with other lanes
- Actual changed files are within claimed paths
- No actual file overlap with other lanes
- No changes to protected paths
- Checks have been run against the current diff

### Check (user-defined verification)
Runs configured commands (e.g., `npm test`, `npm run typecheck`) and records results. Check results are bound to the diff hash — if code changes after a check, the check is invalidated.

### Ready (completion gate)
All gate checks pass + all configured checks pass for the current diff = ready.

## Lane Identification (Three-Tier)

1. **Codex Hook Identity**: Uses `session_id` and `agent_id` from hook JSON stdin to look up lane binding in the `thread_bindings` table.
2. **Git Workspace Identity**: Matches current git branch or worktree path to a known lane.
3. **Local Fallback**: Last-resort mapping stored in `.git/parts/current_lane_by_cwd.json`.

## State Schema

Lane state is stored in `.git/parts/state.sqlite` with these tables:

- `lanes`: Core lane records (id, state, task_summary, task_revision, branch, worktree, session_id, agent_id, timestamps)
- `claims`: Path claims per lane (lane_id, pattern, timestamp)
- `observed_files`: Files actually changed per lane (lane_id, path, diff_hash, timestamp)
- `checks`: Check execution results (lane_id, name, command, exit_code, status, duration_ms, diff_hash, stdout_tail, stderr_tail, timestamp)
- `events`: Event log for auditing (lane_id, type, payload_json, timestamp)
- `thread_bindings`: Maps Codex session/agent IDs to lanes (session_id, agent_id, lane_id, cwd, status)
