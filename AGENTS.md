# Codex Instructions

Read and follow: docs/AI_SHARED_CONTEXT.md

## Project Scope

This repository is a reusable deployment kit for Sub2API + New API + Codex.
It should remain generic and must not contain machine-specific paths, real
credentials, cookies, OAuth tokens, API keys, or local database/log output.

## Codex Role

- Act as the primary implementer unless the user asks otherwise.
- Own final code edits, verification, and the user-facing summary.
- Ask Claude Code for review, architecture feedback, debugging help, or a second opinion when useful.
- Before editing, state the intended files and keep edits scoped.

## Verification

- Run `bash -n scripts/install.sh scripts/validate.sh` after editing shell scripts.
- Before publishing, scan for hard-coded personal paths, planning-stage wording, and credential patterns.
- Do not run the installer in a way that commits generated runtime data.
