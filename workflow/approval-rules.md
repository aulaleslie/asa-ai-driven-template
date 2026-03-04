# Approval Rules

## Core Rules

1. Human approval is mandatory for every stage transition.
2. No role may approve its own authored work.
3. Approval entries must reference artifact paths and a record reference.
4. Rejections must include concrete corrections and owner.
5. Approval outcomes must be logged in governance artifacts.
6. Stage gate approvals use command `approve stage <stage>` and must match current stage.
7. Next-stage transition is forbidden until current stage approval record exists.
8. Use `preflight` before `approve stage` to surface missing artifacts and blockers.

## Separation of Duties

- Author and approver identities must differ.
- Technical approvals require technical reviewers.
- Business approvals require business owners.
- Release approval requires review of deployment evidence.
- Manual-test gate approval requires a human reviewer (not the issue author).

## Manual-Test Gate Rules

1. Manual-test gate approval is forbidden when `open_manual_issues > 0`.
2. Manual-test rejections must reference issue IDs (`MTI-###`) requiring rework.
3. Manual test evidence must include script, execution, feedback, and issues artifacts.
4. Quality -> release transition is blocked until manual-test gate is approved.

## Stack Change Override Process

Stack is immutable after lock unless all conditions are met:

1. Override request logged in `00-governance/decisions.md` with rationale.
2. Impact analysis included (architecture, delivery, quality, release).
3. Explicit human approval by an authority not authoring the change.
4. Override event recorded in `00-governance/command-log.md`.

Without all four, stack changes are invalid.

## Audit Trail Requirements

Each decision entry includes:

- Timestamp
- Stage
- Artifact(s)
- Decision (`approved`, `rejected`, `blocked`)
- Decision maker
- Notes
