---
name: codex-cli
description: >
  Use Codex CLI to review code or analyze the repository. Prefer read-only and on-request approval.
user-invocable: true
allowed-tools:
  - Bash
---

# codex-cli skill

## Default safety
Always run Codex with:
- `--sandbox read-only`
- `--ask-for-approval on-request`

## How to run
Use `scripts/codex_run.sh` and pass:
- mode: review|analyze|investigate|refactor|explain
- target: file/dir or question

## Output format
- Summary (3-7 bullets)
- Findings with evidence (file path + line ranges if available)
- Recommended actions (no edits applied)
