---
name: document-changes
description: Scan recent git changes and update or create relevant documentation files. Use after making significant changes to the codebase.
---

# Document Changes

Analyzes recent git commits/changes and ensures documentation stays in sync. Creates or updates docs based on what changed.

## Usage

The agent should:
1. Run `git log --oneline -10` to see recent commits
2. Run `git diff HEAD~5 --stat` to see what files have changed recently
3. For each changed area:
   - If a Helm chart changed → check/update `docs/deployment.md` or chart-specific docs
   - If config files changed → update relevant docs in `config/` or `docs/`
   - If architecture changes → update `docs/architecture.md`
   - If new components added → document in the appropriate layer doc
4. List what docs were created/updated

Create docs if they don't exist. Don't update `opensas.md` (the one-pager) — that's a canonical reference that requires manual curation.
