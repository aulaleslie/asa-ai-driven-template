# Agent Constitution

This constitution defines non-negotiable operating rules for all agents and humans in this repository.

## Non-Negotiable Rules

1. Document-first workflow is mandatory.
   - No stage is complete without durable artifacts in the project workspace.
2. Agent specialization is strict.
   - Each role operates only within its `CONTRACT.md`.
3. Human approval gates are mandatory.
   - Every stage transition requires explicit human approval.
4. No self-approval.
   - A role or agent cannot approve artifacts it authored.
5. Explicit handoffs only.
   - Sender, receiver, artifacts, open risks, and requested action must be documented.
6. Artifact-required work.
   - Decisions and actions must be reflected in versioned artifacts.
7. Project state tracking is mandatory.
   - Canonical state is `00-governance/project-state.yaml` in repository root.
8. Command execution must use dispatcher.
   - Workflow commands must run via `scripts/command-dispatch.sh`.
   - No alternate gate entry points are allowed for stage progression.
9. Stack lock governance is mandatory.
   - Stack cannot change after lock unless a human override is recorded in `00-governance/decisions.md` and approved.
10. Manual-test quality gate is mandatory.
    - Quality cannot pass without human execution of generated manual test script.
11. Manual-test issue loop is strict.
    - Any open manual-test issue blocks manual-test gate approval.
12. Release deployability evidence is mandatory.
    - Release approval requires evidence for deployment using `docker compose up --build -d`.
13. In-repo scaffolding only.
   - Agents must scaffold within the current repository and must not create a new repository.
14. Single-project policy is mandatory.
   - One template clone supports one project workspace only.
   - Repeated create-project intake commands must be rejected with guidance to extend current scope or start a next phase.
15. Phase-cycle governance is mandatory.
   - Initial create-project command only captures big-picture expectation and phase-1 MVP objective.
   - Additional human requirements must use `start next phase: <goal>` after release approval.
16. Delivery is execution-first.
   - During delivery, active tickets must drive implementation work before producing additional planning artifacts.
17. No timeline estimation by default.
    - Date/time estimates are optional and only provided when explicitly requested by a human.
18. Stage progression is approval-locked.
    - No stage transition may occur until the current stage is explicitly approved via gate command.
19. Stack-aware engineering method is mandatory.
    - Delivery must follow test-driven development and domain-driven design by default.
    - If a stack requires a different but equivalent approach, Solution Architect must document the stack-suited method and SDET must validate it.

## Required Operating Behavior

- Every response includes stage and current item context.
- Every state-changing command writes to `00-governance/command-log.md`.
- Rejections include concrete correction notes and owner.
- Assumptions, decisions, and approvals are logged in governance files.
- Manual-test issues must use `MTI-###` identifiers and lifecycle states.
- Delivery/quality artifacts must include stack-aware TDD + domain-model evidence.

## Stage Gate Outcomes

- `approved`
- `rejected`
- `blocked`

Rejected work stays in the same stage until corrected and re-reviewed.

## Handoff Minimum Packet

A handoff is invalid unless it includes:

- Source role and target role
- Stage and item reference
- Artifact index with paths
- Stack profile reference
- Development method evidence reference (TDD/DDD or approved stack-suited equivalent)
- Deployment impact summary
- Manual-test evidence reference for quality/release
- Open risks and questions
- Requested action

## Override Protocol

If exceptional changes are required:

1. Document justification in `decisions.md`.
2. Record approver and date.
3. Log impacted artifacts and rollback considerations.

No override is valid without explicit human approval.
