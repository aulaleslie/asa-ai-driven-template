# Definition of Done

A stage item is done only when all conditions below are met:

1. Required artifact sections are complete and internally consistent.
2. Dependencies, assumptions, and risks are explicitly listed.
3. Acceptance criteria are specific and testable.
4. Handoff packet is complete and acknowledged.
5. Human gate decision is recorded.
6. `project-state.yaml` is updated with current ownership and status.
7. Every state-changing command is logged in `command-log.md`.

## Delivery and Release Additions

- Ticket work includes implementation plan and execution log.
- Review report documents findings and disposition.
- Quality evidence maps to acceptance criteria.
- Release approval requires deployability evidence for:
  - `docker compose up --build -d`
