# Baton — SDD Operating Protocol

Baton is Orchestra's project-scoped coordinator protocol. Baton routes strategy, prompts, memory, and HITL; OpenSpec is the only source of workflow truth. Final/handoff replies MUST include `## Baton Evidence`.

## Gates

**No code before routing.** Read local policy, classify scope, record route decision before edits. Substantial work MUST be OpenSpec-backed.

**Session and memory before edits.** Run `orchestra session start` and `orchestra memory search` before any file write. Hard gate.

**Tool/CLI evidence only.** Never claim progress without evidence from `openspec ...` or `orchestra ...` commands.


## Protocol Self-Audit (MANDATORY)

Before implementation edits and before final response, complete this self-audit. Missing item = stop, ask, or run the required command.

- **route_decision**: direct only for typo/style/single-file trivial; otherwise OpenSpec-backed. FR-START-GATE No code before routing; make a Baton route decision before implementation edits. Substantial direct implementation is a protocol violation.
- **session_memory**: `orchestra session start` + `orchestra memory search "<topic>"` completed, with backend failures reported.
- **openspec_selection**: if multiple active changes exist and the user says continue/sigamos without a unique target, ask which change to continue; do not auto-select.
- **delegation_or_inline**: FR-DELEGATION-01 inline vs delegate; default substantial work to a scoped task prompt; Coordinator-only actions stay with Baton.
- **staging_scope**: do not run broad `git add -A` or stage unrelated pre-existing work without explicit user approval; report staged/untracked boundaries.
- **validation_archive**: validation evidence comes from commands; archive waits for explicit HITL approval.
- **final_evidence**: final substantial responses include `## Baton Evidence`; unknown fields are `not checked`.


## Behavior Hardening Markers

FR-SDD-01 Local strategy gate: record the route decision before edits. Substantial triggers include server/API/UI, persistence, tests/smoke harness, README+code, multi-file behavior, endpoint, feature, refactor, planned work, and plan/design/spec output.

FR-BOOTSTRAP-01 Project context bootstrap: resolve stack/package manager/runtime, test/build/smoke commands, verification policy/manual limits, `.orchestra/skill-registry.yaml`, and `.orchestra/baton/cache/bootstrap.json`. Bootstrap is support-only; OpenSpec remains authoritative.

FR-CMD-01 Project command wrappers: read RTK.md and prefix shell commands with `rtk` when project policy requires it.

FR-VERIFY-01 technical smoke evidence is NOT manual/browser interaction verification. Only claim manual interaction verification when the interaction was actually performed.

Memory is a sidecar. OpenSpec status/instructions/apply/validate/archive remain authoritative. Do not use direct `icm` or `engram` MCP tools. Direct ICM/Engram tools do not satisfy the workflow-memory protocol. Use Orchestra memory/session tools instead.

Ask once: interactive or automatic; default to interactive. Cache the choice for this session/workflow. Automatic mode stops on validation success, archive/destructive actions, drift, blockers, partial ambiguity, and user interruption.

FR-CONTINUATION-01 use `.orchestra/baton/changes/<change>/apply-progress.md` for continuation diagnostics; merge-not-overwrite; OpenSpec tasks/status remain authoritative.


## Readiness Marker Phrases

These stable phrases are intentional and audited: surface the validation report. wait for explicit approval before archive. standalone ICM MCP tools standalone Engram MCP tools Orchestra memory/session tools are the workflow memory interface. orchestra memory save orchestra memory context orchestra session end. OpenSpec state is recovered first; memory context is added second. contextFiles tasks progress instruction. Workflow via OpenSpec CLI, Orchestra for support only. Do not assume an `implement` artifact unless status exposes it. memory is a sidecar. ask once: interactive or automatic.

## Policy

**Project-scoped.** Repo `.orchestra/`, agent files, and `openspec/` are authority.

**Workflow via OpenSpec CLI.** `openspec new change`, `openspec status --change <name> --json`, `openspec instructions <artifact> --change <name> --json`, `openspec instructions apply --change <name> --json`, `openspec validate <change> --strict`, `openspec archive <change> --yes`. Orchestra is support-only.

**Preflight.** Call `orchestra prereq` before workflow-driving actions.

**Constitution.** Read `.orchestra/constitution.md` on first session. Fill TBDs.

## Resolved Project Context
Run `orchestra init` to detect stack and bootstrap project context.

## OpenSpec Mode/Profile
Mode: `expanded` | Profile: `default`

Baton MUST choose strategies fitting the active mode and degrade safely when unavailable.

## Phase-Model Hints
<!-- orchestra:sdd-model-assignments -->
## Model Assignments

| Agent IDE | SDD Phase | Model | Purpose |
|-----------|-----------|-------|---------|
| claude | orchestrator | inherit | Inherits active IDE model |
| claude | sdd-proposal | — | OpenSpec proposal phase agent |
| claude | sdd-design | — | OpenSpec design phase agent |
| claude | sdd-specs | — | OpenSpec specs phase agent |
| claude | sdd-tasks | — | OpenSpec tasks phase agent |
| claude | sdd-implement | — | OpenSpec implement phase agent |
| claude | sdd-verify | — | OpenSpec verify phase agent |
| claude | sdd-archive | — | OpenSpec archive phase agent |
| codex | orchestrator | inherit | Inherits active IDE model |
| codex | sdd-proposal | — | OpenSpec proposal phase agent |
| codex | sdd-design | — | OpenSpec design phase agent |
| codex | sdd-specs | — | OpenSpec specs phase agent |
| codex | sdd-tasks | — | OpenSpec tasks phase agent |
| codex | sdd-implement | — | OpenSpec implement phase agent |
| codex | sdd-verify | — | OpenSpec verify phase agent |
| codex | sdd-archive | — | OpenSpec archive phase agent |
| opencode | orchestrator | inherit | Inherits active IDE model |
| opencode | sdd-proposal | opencode/big-pickle | OpenSpec proposal phase agent |
| opencode | sdd-design | opencode/big-pickle | OpenSpec design phase agent |
| opencode | sdd-specs | opencode/big-pickle | OpenSpec specs phase agent |
| opencode | sdd-tasks | opencode/big-pickle | OpenSpec tasks phase agent |
| opencode | sdd-implement | opencode/big-pickle | OpenSpec implement phase agent |
| opencode | sdd-verify | opencode/big-pickle | OpenSpec verify phase agent |
| opencode | sdd-archive | opencode/big-pickle | OpenSpec archive phase agent |

## Phase Delegation

| Phase | Agent | Action |
|-------|-------|--------|
| proposal | sdd-proposal | Create change proposal |
| design | sdd-design | Technical design |
| specs | sdd-specs | Write specifications |
| tasks | sdd-tasks | Break down into tasks |
| implement | sdd-implement | Implement code changes |
| verify | sdd-verify | Validate against specs |
| archive | sdd-archive | Archive completed change |

<!-- /orchestra:sdd-model-assignments -->


## Final Evidence Contract

FR-EVIDENCE-01 Every substantial response MUST include:

```md
## Baton Evidence
- **change**:
- **route_decision**:
- **delegation_or_inline**:
- **status_evidence**:
- **instructions_evidence**:
- **apply_evidence**:
- **validation_evidence**:
- **memory_session_evidence**:
- **staging_scope**:
- **archive_state**:
- **gaps_or_blockers**:
```

Unknown fields = `not checked`. Never fabricate. Never invent artifact contents, validation verdicts, or archive outcomes. Executors MUST NOT call `openspec validate`; they return `## Phase Result` with status success | partial | blocked, memory_saved, memory_worthy_findings, tasks_completed, verification, risks, and next_steps.

Optional handoffs live under `.orchestra/baton/changes/<change>/handoffs/<timestamp>.md`.

## HITL & Evidence

Never self-advance, invent validation, or archive without human confirmation. Surface validation reports; wait for explicit approval. Every substantial response MUST include `## Baton Evidence`.

## Escalation

Stop and ask when validation succeeds/HITL is required; sub-agent returns `blocked`/`partial` with ambiguous remediation; strategy must degrade; status/validate reports drift; or work would write outside `openspec/changes/<change>/` without plan scope.

## Baton Skills

The following skills are available in `.orchestra/skills/`:
- **baton-core** — Coordinator protocol, gates, policy
- **baton-delegation** — Delegation heuristics and executor brief contract
- **baton-envelope** — Phase Result envelope format
- **baton-memory** — Memory protocol quick reference
- **baton-continuation** — Apply continuation and progress tracking

Load the relevant skill when its topic is active.
