# Delivery Lifecycle

This framework runs as a command-driven, document-first state machine.

## Operation Model

1. Commands are executed through `scripts/command-dispatch.sh`.
2. Dispatcher validates guards, applies deterministic updates, and logs outcomes.
3. Human approvals control stage gates and sensitive changes.
4. Project state, command logs, approvals, and handoffs are the operational source of truth.
5. Project scaffolding is always in-place in the current repository.

## Stack Lock Checkpoint

- Intake starts with the initial command containing stack values.
- Stack profile is written to `00-governance/stack-lock.yaml`.
- `stack_locked: true` is required before moving beyond Discovery.

## 1. Intake

- Intent: capture request and initialize stack profile.
- Outputs: intake request, stack lock, initial state.
- Gate: human intake confirmation.
- Next role: Project Manager.

## 2. Discovery

- Intent: define scope and discovery artifacts.
- Outputs: charter, scope in/out, open questions.
- Gate: human scope approval.
- Next role: Business Analyst.

## 3. Analysis

- Intent: produce business requirements and rule clarity.
- Outputs: BRD, stories, business rules, glossary.
- Gate: human requirements approval.
- Next role: Solution Architect.

## 4. Architecture

- Intent: define technical structure and constraints.
- Outputs: architecture, NFRs, C4, ADRs.
- Gate: human architecture approval.
- Next role: UI/UX Designer and Data Engineer.

## 5. Design

- Intent: define UX behavior and component mapping.
- Outputs: UX flows, wireframes, component map.
- Gate: human design approval.
- Next role: Project Manager.

## 6. Planning

- Intent: create executable epics/tickets and dependency order.
- Outputs: delivery sequence, epics, tickets, execution plan (no required calendar timeline).
- Gate: human delivery plan approval.
- Next role: Software Developer.

## 7. Delivery

- Intent: execute tickets with explicit handoff packets and code-first progress on the active ticket.
- Outputs: ticket artifacts, implementation plan, review report.
- Gate: human acceptance of delivery evidence.
- Next role: SDET.

## 8. Quality

- Intent: validate acceptance and deployability contract.
- Outputs: test strategy, acceptance cases, QA report, manual test runbook/execution/issues, deployability validation evidence.
- Gate: human quality approval only after manual-test gate approval and zero open manual-test issues.
- Next role: Project Manager.

## 9. Release

- Intent: approve and document release.
- Outputs: release readiness, release notes, known issues, deployment references.
- Gate: human release approval with compose deployability evidence.
- Next role: Project Manager for closure.

## Transition Rule

No transition is valid without:

1. Required artifacts.
2. Human gate outcome.
3. Updated `project-state.yaml`.
4. Command audit entry in `command-log.md`.
5. For quality -> release, `manual_test_gate_status=approved` and `open_manual_issues=0`.
