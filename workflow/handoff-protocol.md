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
8. `summary`
9. `open_risks`
10. `open_questions`
11. `requested_action`
12. `due_by`

## Handoff Rules

- Sender must ensure artifacts are current and linked.
- Receiver must acknowledge handoff status within agreed SLA.
- `stack_profile_ref` must point to `00-governance/stack-lock.yaml`.
- Deployment-impact section is mandatory for delivery, quality, and release handoffs.
- If rejected, receiver must provide concrete correction notes.
- Rejected handoffs return to sender without stage advancement.
- Accepted handoffs must update project state (`next_actor`, `last_actor`, `current_item`).

## Acknowledgment Outcomes

- `accepted`
- `accepted_with_conditions`
- `rejected`
- `blocked`
