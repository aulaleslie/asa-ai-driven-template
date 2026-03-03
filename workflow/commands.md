# Command Contract

All workflow commands are executed through:

- `./scripts/command-dispatch.sh --command "<phrase>" [--project <slug>] --actor <actor-id>`

## Command Specification

| Command ID | Exact Syntax | Required Stage | Preconditions | Side Effects | Failure Conditions |
| --- | --- | --- | --- | --- | --- |
| intake_start | `to project manager: I want to build <product-name> | fe=<fe> | be=<be> | db=<db> | cache=<cache>` | none | Stack values in allowlist | Initialize project if missing, write stack lock, set `stack_locked=true`, log command | Invalid format, invalid stack values, stack override attempt without approved decision |
| review_scope | `review scope` | discovery | Project exists | Set `current_item=scope-review`, log command | Missing project state |
| lock_scope | `lock scope` | discovery | Discovery artifacts exist; discovery approval logged | Set `scope_locked=true`, set `current_item=scope-locked`, log command | Missing artifacts, missing approval, wrong stage |
| generate_epics | `generate epics` | planning | `scope_locked=true`; BRD approval exists | Ensure planning artifacts exist, set `current_item=epics`, log command | Scope unlocked, missing approval, missing project |
| start_epic | `start epic-<n>` | delivery | Epic id format valid | Set `active_epic`, ensure epic folder/file, set delivery context, log command | Invalid epic format, project missing |
| start_ticket | `start epic-<n>-ticket-<n>` | delivery | Epic and ticket format valid | Set `active_epic`, `active_ticket`, scaffold ticket packet if needed, log command | Invalid format, wrong stage, ticket scaffold failure |
| approve_brd | `approve BRD` | analysis | BRD exists | Append approval log entry, add BRD to approved artifacts, log command | BRD missing |
| reject_architecture | `reject Architecture with notes: <text>` | architecture | Architecture doc exists; notes non-empty | Append rejection entry to approvals, set status context, log command | Missing notes, architecture doc missing |
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
