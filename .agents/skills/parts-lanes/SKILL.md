---
name: parts-lanes
description: Use this skill whenever editing code in a Git repository with Codex threads, subagents, worktrees, or parallel AI sessions. It prevents agents from editing the same files, losing track of their current task, or claiming completion before lane checks pass.
---

# Parts Lanes Skill

You are working in a repository that uses Parts Lanes.

Your goal is to complete the user's coding task while staying inside your own Lane and avoiding collisions with other AI or human work.

## Core rules

1. Never edit code before identifying your Lane.
2. A Lane may exist before it has a task.
3. The user may define or change your task after the Lane exists.
4. Changing the task does not automatically allow new file paths.
5. Claim paths before editing them.
6. Sync after edits.
7. Run gate before reporting progress.
8. Run ready before claiming completion.

## Required workflow

### 1. Identify the current Lane

Run:

```bash
./parts-lane current
```

If there is no Lane, run:

```bash
./parts-lane begin
```

### 2. Set or update the task

If the Lane has no task, summarize the user's instruction and run:

```bash
./parts-lane task set "<task summary>"
```

If the user changes the task, run:

```bash
./parts-lane task update "<new task summary>"
```

### 3. Claim paths before editing

After inspecting the repo, claim likely paths:

```bash
./parts-lane claim "src/auth/**" "tests/auth/**"
```

If claim fails, stop and report the collision.

### 4. Edit only claimed paths

If you need another path, use:

```bash
./parts-lane claim-add "new/path/**"
```

### 5. Sync after editing

```bash
./parts-lane sync
```

### 6. Gate before progress

```bash
./parts-lane gate
```

### 7. Check and ready before completion

```bash
./parts-lane check
./parts-lane ready
```

Only claim completion if ready passes.

## Never do these

- Do not work on protected branches directly.
- Do not edit unclaimed paths.
- Do not ignore claim conflicts.
- Do not claim tests passed unless `parts-lane check` recorded them after the latest diff.
- Do not directly edit `.git/parts` state.
- Do not delete or modify another Lane.

Use `./parts-lane` from the repository root when available; otherwise use
`.agents/skills/parts-lanes/scripts/parts-lane`.
