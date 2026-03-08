# Command Contract

All workflow commands are executed through a single entry point:

- `./scripts/command-dispatch.sh --command "<phrase>" [--project <root>] --actor <actor-id>`
- Single-project mode: `--project` is optional and may only be `.` or `root`.
- If `--project` is omitted, dispatcher targets root workspace (`./00-governance/project-state.yaml`) when present.
- Dispatcher accepts free-form human intent and canonicalizes it to workflow commands before execution.

## Command Specification

| Command ID | Canonical Syntax (examples) | Required Stage | Preconditions | Side Effects | Failure Conditions |
| --- | --- | --- | --- | --- | --- |
| intake_start | `to project manager: I want to build <product-name> | fe=<fe> | be=<be> | db=<db> | cache=<cache>` | none | Stack values in allowlist; no existing root workspace | Initialize root workspace in current repository if missing, write stack lock, set `stack_locked=true`, initialize `phase-1` as MVP big-picture request, log command | Invalid format, invalid stack values, or project already initialized (single-project policy) |
| set_phase_plan | `set phase plan: <phase-2-goal>; <phase-3-goal>; ...` | intake | Project exists; at least one phase goal provided | Appends future phases (`phase-2+`) as `planned` in `00-governance/phases.md`, updates `01-intake/Phase_0_Plan.md`, logs command | Wrong stage, empty goals, duplicate phase rows |
| execute_phase | `execute phase <n>` or `proceed phase <n>` | any | Project exists; target phase is current or next sequential; if next phase then current phase release must be approved and phase goal must be planned | If current phase: resumes context; if next phase: promotes planned phase to active and starts next discovery cycle, logs command | Non-sequential target, missing planned goal, release not approved |
| review_scope | `review scope` | intake,discovery | Project exists | Ensure discovery context, set `current_item=scope-review`, log command | Missing project state |
| start_next_phase | `start next phase: <goal>` | release | Release stage approved in current phase | Close previous phase record, archive/reset approvals, initialize next phase context at discovery, reset scope lock, log command | Missing release approval, invalid format, wrong stage |
| lock_scope | `lock scope` | discovery | Discovery artifacts exist; discovery approval logged | Set `scope_locked=true`, set `current_item=scope-locked`, log command | Missing artifacts, missing approval, wrong stage |
| generate_epics | `generate epics` | analysis,planning | `scope_locked=true`; BRD approval exists | Ensure planning artifacts exist, set planning context and `current_item=epics`, log command | Scope unlocked, missing approval, missing project |
| start_epic | `start epic-<n>` | planning,delivery | Epic id format valid | Set `active_epic`, ensure epic folder/file, set delivery context, log command | Invalid epic format, project missing |
| start_ticket | `start epic-<n>-ticket-<n>` | delivery | Epic and ticket format valid | Set `active_epic`, `active_ticket`, scaffold ticket packet if needed, log command | Invalid format, wrong stage, ticket scaffold failure |
| execute_ticket | `execute current ticket` | delivery | Active epic/ticket exists | Set execution context for active ticket, set next actor `software-developer`, log command | Missing active ticket, missing ticket directory, wrong stage |
| preflight | `preflight` | any | Project exists | Print exact gate/artifact blockers for current stage progression | Missing project state |
| advance_stage | `advance stage` | any | Current stage has explicit approval record | Transition to next stage from state machine, update stage context, log command | Current stage not approved, transition blocked by gate checks |
| approve_brd | `approve BRD` | analysis | BRD exists | Append approval log entry, add BRD to approved artifacts, log command | BRD missing |
| approve_stage | `approve stage <intake|discovery|analysis|architecture|design|planning|delivery|quality|release>` | any | Target stage matches `current_stage`; quality/release extra guards pass; delivery/quality require stack-aware TDD/domain evidence | Append stage approval to approvals log, mark stage approved in state, log command | Stage mismatch, missing quality/release prerequisites, missing TDD/domain evidence |
| reject_architecture | `reject Architecture with notes: <text>` | architecture | Architecture doc exists; notes non-empty | Append rejection entry to approvals, set status context, log command | Missing notes, architecture doc missing |
| prepare_manual_test | `prepare manual test` | quality | Acceptance test cases exist | Generate `08-quality/Manual_Test_Script.md`, set `manual_test_gate_status=prepared`, log command | Missing acceptance test cases, wrong stage |
| start_manual_test | `start manual test` | quality | `manual_test_gate_status=prepared` | Set `manual_test_gate_status=in_progress`, log command | Manual test not prepared, wrong stage |
| submit_manual_test_failed | `submit manual test failed: <title> | severity=<critical|high|medium|low> | details=<text>` | quality | `manual_test_gate_status` in `prepared` or `in_progress` or `failed` | Create issue `MTI-###`, append feedback, set `manual_test_gate_status=failed`, increment `open_manual_issues`, set `next_actor=software-developer`, log command | Invalid format, severity invalid, wrong stage |
| resolve_manual_issue | `resolve manual issue MTI-<n> with notes: <text>` | quality | Issue exists and status `open` | Set issue status `resolved_pending_retest`, set `next_actor=sdet`, log command | Missing issue, issue not open, missing notes |
| retest_manual_issue_passed | `retest manual issue MTI-<n> passed` | quality | Issue exists and status `resolved_pending_retest` | Set issue status `closed`, decrement `open_manual_issues`, log command | Missing issue, invalid status |
| retest_manual_issue_failed | `retest manual issue MTI-<n> failed: <text>` | quality | Issue exists and status `resolved_pending_retest` | Set issue status `open`, set gate status `failed`, append retest failure detail, log command | Missing issue, invalid status, missing notes |
| submit_manual_test_passed | `submit manual test passed` | quality | `open_manual_issues=0` and gate status not `not_started` | Set `manual_test_gate_status=passed`, `manual_test_last_result=passed`, log command | Open manual issues exist, manual test not started |
| approve_manual_test_gate | `approve manual test gate` | quality | `manual_test_gate_status=passed`; `open_manual_issues=0`; manual artifacts exist | Append approval record, set `manual_test_gate_status=approved`, log command | Open issues, missing artifacts, invalid gate status |
| show_blockers | `show blockers` | any | Project exists | Print blocker summary from state | Missing project state |
| resume_stage | `resume current stage` | any | Project exists | Re-emit stage context summary, log command | Missing project state |
| close_ticket | `close ticket` | delivery | Active ticket set; ticket, handoff, implementation plan, review report exist | Mark ticket closed context, clear active ticket, set next actor `sdet`, log command | Missing active ticket, missing required files |

Notes:
- Command phrases are not rigid; canonical syntax shown above is the normalized form used internally.
- Intake parsing is whitespace-tolerant around `|` separators and normalizes stack values to lowercase before allowlist validation.
- Table-backed artifacts sanitize command/note cells so conversational text does not corrupt markdown table structure.
- Phase 0 planning is represented by `01-intake/Phase_0_Plan.md` and planned rows in `00-governance/phases.md`.
- Prefer `execute phase <n>` for human-level progression; `start next phase: <goal>` remains available for ad-hoc goals.

## Curated Stack Allowlist

- FE: `next`
- BE: `nest`
- DB: `sqlite`, `postgres`, `mysql`
- Cache: `redis`, `none`

## Guard and Mutation Policy

1. Guard failure returns non-zero and does not mutate project state.
2. Every state-changing command writes a row to `00-governance/command-log.md`.
3. Stack changes after lock require explicit human override in `decisions.md`.
4. `close ticket` requires complete delivery evidence before handoff.
5. Manual-test gate cannot be approved while `open_manual_issues > 0`.
6. Stage transitions are blocked until current stage has an explicit approval record.
7. Scaffolding commands operate only inside the current repository and never create a new repository.
8. Command phrase matching and required-stage enforcement are sourced from `workflow/command-registry.yaml`.
9. `intake_start` is one-time project creation. Additional human requests should use `execute phase <n>` (or `start next phase: <goal>`) instead of creating a second project.
10. Delivery and quality stage approvals require stack-aware TDD/domain-method evidence.

## Minimal Gate Flow

1. `to project manager: I want to build <product-name> | fe=<fe> | be=<be> | db=<db> | cache=<cache>`
2. Optional during intake: `set phase plan: <phase-2 goal>; <phase-3 goal>`
3. `preflight`
4. `approve stage intake`
5. `advance stage`
6. Stage-specific work commands (for example `review scope`, `lock scope`, `generate epics`, `start epic-1`, `execute current ticket`)
7. `preflight`
8. `approve stage <current_stage>`
9. `advance stage`
10. After release approval: `execute phase <n>` (or `start next phase: <goal>`)
