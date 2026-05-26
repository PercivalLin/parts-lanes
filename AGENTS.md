# AGENTS.md

This repository uses Parts Lanes.

For every coding task, use the `parts-lanes` skill before editing code.

Required workflow:

1. Identify or create your current Lane.
2. Set or update the Lane task after the user gives instructions.
3. Claim the files or directories you expect to modify.
4. Work only inside your Lane workspace.
5. Sync actual changed files after edits.
6. Run gate checks before claiming progress.
7. Run ready checks before claiming completion.

Never claim completion unless `parts-lane ready` reports ready.

Do not directly edit Lane state files. Use the `parts-lane` script only.
