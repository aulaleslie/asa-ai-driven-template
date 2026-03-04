# Handoff Protocol

## Purpose

Define strict, explicit handoffs between specialized agents and humans.

## Required Packet Fields

1. `from_role`
2. `to_role`
3. `stage`
4. `item_reference`
5. `artifacts` (paths)
6. `stack_profile_ref`
7. `deployment_impact`
8. `manual_test_evidence_ref` (quality/release handoffs)
9. `summary`
10. `open_risks`
11. `open_questions`
12. `requested_action`

## Handoff Rules

- Sender must ensure artifacts are current and linked.
- Receiver acknowledges handoff status when triggered by human workflow.
- `stack_profile_ref` must point to `00-governance/stack-lock.yaml`.
- Deployment-impact section is mandatory for delivery, quality, and release handoffs.
- Quality/release handoffs must include `manual_test_evidence_ref`.
- If rejected, receiver must provide concrete correction notes.
- Rejected handoffs return to sender without stage advancement.
- Accepted handoffs must update project state (`next_actor`, `last_actor`, `current_item`).

## Acknowledgment Outcomes

- `accepted`
- `accepted_with_conditions`
- `rejected`
- `blocked`
