# Approval Rules

## Core Rules

1. Human approval is mandatory for every stage transition.
2. No role may approve its own authored work.
3. Approval entries must reference artifact paths and date.
4. Rejections must include concrete corrections and owner.
5. Approval outcomes must be logged in governance artifacts.

## Separation of Duties

- Author and approver identities must differ.
- Technical approvals require technical reviewers.
- Business approvals require business owners.
- Release approval requires review of deployment evidence.

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
