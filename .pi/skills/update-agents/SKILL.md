---
name: update-agents
description: Review current repo conventions, directory structure, and patterns, then update AGENTS.md to reflect any new conventions established during recent work.
---

# Update AGENTS.md

Reviews the current state of the repository and updates AGENTS.md (this file) with any new conventions, directory patterns, or guidelines that have been established but not yet documented.

## Usage

The agent should:
1. Read the current `AGENTS.md`
2. Scan the repo structure: `find . -maxdepth 3 -type d | grep -v '.git' | sort`
3. Identify any new conventions or patterns that emerged during recent work
4. Check for:
   - New directories that should be listed in the structure section
   - New naming conventions that should be documented
   - New architectural patterns or design decisions
   - New tools or technologies adopted
5. Update `AGENTS.md` to reflect these
6. Run `/reload` afterward (tell the user to do this if running non-interactively)

Do NOT remove existing conventions. Only add or clarify.
