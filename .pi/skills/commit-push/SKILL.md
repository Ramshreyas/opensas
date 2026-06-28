---
name: commit-push
description: Stage all changes, generate a conventional commit message from git diff, commit, and push to the remote branch. Use after making changes to the repo.
---

# Commit & Push

Stages all changes, analyzes the diff to produce a Conventional Commit message, commits, and pushes.

## Usage

```bash
# Stage all changes, commit with auto-generated message, push
git add -A
git diff --cached --stat   # preview what's staged
```

The agent should:
1. Run `git add -A` to stage everything
2. Run `git diff --cached --stat` to preview staged files
3. Generate a conventional commit message based on the changes (scan the actual diff)
4. Run `git commit -m "<type>(<scope>): <message>"`
5. Run `git push` to push the current branch

The commit message must follow the Conventional Commits format:
`<type>(<scope>): <description>`

Types: `feat`, `fix`, `docs`, `chore`, `refactor`, `test`, `ci`, `style`, `perf`
Scopes: `infra`, `interfaces`, `orchestration`, `data`, `charts`, `docs`, `ci`, `agents`
