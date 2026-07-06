# Shared AI Context

## Default Collaboration Model

- Codex App and Claude Code may work in the same local working directory.
- Codex is the primary implementer by default.
- Claude Code is primarily the reviewer, architect, debugger, or second opinion by default.
- The user is the final coordinator and decides when work is ready.

## Required Project Bootstrap

- At the start of work in any new project or task directory, check whether these files exist:
  - `AGENTS.md`
  - `CLAUDE.md`
  - `docs/AI_SHARED_CONTEXT.md`
- If any are missing, run `ai-shared-init` from the project root before substantive work.
- If `ai-shared-init` is unavailable, create equivalent files manually using this shared context.

## Coordination Rules

- Only one agent should write files at a time.
- Before editing, state which files are expected to change.
- Do not overwrite uncommitted changes from the user or another agent.
- Use `git status --short` before substantial edits.
- Use `git diff` after substantial edits and before handing work off.
- Prefer read-only review when another agent is actively editing.
- Keep unrelated refactors out of the current task.
- If unexpected file changes appear, treat them as user or other-agent work and do not revert them without explicit permission.

## Verification

- Run the relevant tests, type checks, linters, or build commands after code changes.
- If verification cannot run, explain exactly why and what remains unverified.
- Do not claim success without verification or a clear reason verification was skipped.

## Handoff Format

When handing work to the other agent, include:

- Goal
- Files touched
- Current status
- Commands run
- Verification result
- Open questions or risks

## Git Discipline

- Keep changes small enough to review.
- Prefer separate commits for unrelated concerns.
- Do not stage, commit, reset, checkout, or revert changes unless the user asks.
- For parallel implementation experiments, prefer separate git worktrees instead of two agents editing the same checkout.

## Local Project Notes

- This repository packages a reusable gateway installer, not one user's live deployment.
- Do not commit generated runtime directories, local credentials, `.env` files, SQLite databases, logs, cookies, OAuth tokens, account passwords, or API keys.
- Keep public documentation in deployment-ready language; avoid old planning/screening wording such as "recommended path" versus "not recommended path".
- Prefer `$HOME`, `AI_GATEWAY_HOME`, `CODEX_HOME`, and other environment variables over hard-coded user paths.
- Test shell changes with `bash -n scripts/install.sh scripts/validate.sh`.
