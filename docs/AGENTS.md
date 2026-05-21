<!-- orchestra:start -->
Use the `orchestra` agent (Tab to switch) for SDD work. Build agent for direct edits.

@BATON.md
@STACCATO.md

MANDATORY — Before any code edit, file write, or implementation tool invocation:
1. `orchestra session start`
2. `orchestra memory search "<topic>"`

No edits before session+memory. Hard gate — do not skip, do not postpone.

MANDATORY — Protocol self-audit before substantial work and before final response:
- route_decision: direct only for typo/style/single-file trivial; otherwise OpenSpec-backed.
- openspec_selection: with multiple active changes and vague “continue/sigamos”, ask which change; do not auto-select.
- delegation_or_inline: substantial implementation belongs to Baton/executor split; explain any inline exception.
- staging_scope: do not run broad `git add -A` or stage unrelated pre-existing work without explicit approval.
- final_evidence: substantial replies include `## Baton Evidence` with validation, memory/session, staging, archive state, and gaps.

Agent reference:
- `orchestra` (primary) — SDD coordinator, full Baton protocol, delegates to sub-agents
- `baton-executor` (sub) — code implementation, edit+bash, returns Phase Result
- `baton-validator` (sub) — read-only verification, runs tests/linters
- `orchestra-explorer` (sub) — read-only codebase exploration
<!-- orchestra:end -->

### Go Development
- `go-testing` — Go testing patterns (table-driven, teatest, golden files, mocks)
- `go-bubbletea-patterns` — Bubble Tea TUI patterns (screens, navigation, state)
- `go-system-patterns` — System detection & command execution (OS, brew, sudo, exec)
- `go-installer-patterns` — Installer step patterns (InstallStep, execution, logging)
- `go-e2e-patterns` — Docker-based E2E testing patterns
