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
7. `development_method_evidence_ref` (TDD/DDD or approved stack-suited equivalent)
8. `deployment_impact`
9. `manual_test_evidence_ref` (quality/release handoffs)
10. `summary`
11. `open_risks`
12. `open_questions`
13. `requested_action`

## Handoff Rules

- Sender must ensure artifacts are current and linked.
- Receiver acknowledges handoff status when triggered by human workflow.
- `stack_profile_ref` must point to `00-governance/stack-lock.yaml`.
- `development_method_evidence_ref` must point to architecture/test strategy/review evidence showing stack-aware method compliance.
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
