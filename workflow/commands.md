# Command Contract

All workflow commands are executed through:

- `./scripts/command-dispatch.sh --command "<phrase>" [--project <slug>] --actor <actor-id>`

## Command Specification

| Command ID | Exact Syntax | Required Stage | Preconditions | Side Effects | Failure Conditions |
| --- | --- | --- | --- | --- | --- |
| intake_start | `to project manager: I want to build <product-name> | fe=<fe> | be=<be> | db=<db> | cache=<cache>` | none | Stack values in allowlist | Initialize project workspace in current repository if missing, write stack lock, set `stack_locked=true`, log command | Invalid format, invalid stack values, stack override attempt without approved decision |
| review_scope | `review scope` | intake,discovery | Project exists | Ensure discovery context, set `current_item=scope-review`, log command | Missing project state |
| lock_scope | `lock scope` | discovery | Discovery artifacts exist; discovery approval logged | Set `scope_locked=true`, set `current_item=scope-locked`, log command | Missing artifacts, missing approval, wrong stage |
| generate_epics | `generate epics` | analysis,planning | `scope_locked=true`; BRD approval exists | Ensure planning artifacts exist, set planning context and `current_item=epics`, log command | Scope unlocked, missing approval, missing project |
| start_epic | `start epic-<n>` | planning,delivery | Epic id format valid | Set `active_epic`, ensure epic folder/file, set delivery context, log command | Invalid epic format, project missing |
| start_ticket | `start epic-<n>-ticket-<n>` | delivery | Epic and ticket format valid | Set `active_epic`, `active_ticket`, scaffold ticket packet if needed, log command | Invalid format, wrong stage, ticket scaffold failure |
| execute_ticket | `execute current ticket` | delivery | Active epic/ticket exists | Set execution context for active ticket, set next actor `software-developer`, log command | Missing active ticket, missing ticket directory, wrong stage |
| approve_brd | `approve BRD` | analysis | BRD exists | Append approval log entry, add BRD to approved artifacts, log command | BRD missing |
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
6. Scaffolding commands operate only inside the current repository and never create a new repository.
7. Command phrase matching and required-stage enforcement are sourced from `workflow/command-registry.yaml`.
