# Project Workspace Template

Scaffold this workspace in repository root by default and execute delivery via command dispatcher.

## Folder Map

- `00-governance/` state, approvals, assumptions, decisions, stack lock, phase register, command log
- `01-intake/` intake request
- `02-discovery/` charter and scope
- `03-analysis/` requirements and glossary
- `04-architecture/` technical design and ADRs
- `05-design/` UX and component mapping
- `06-planning/` delivery sequence, epics, tickets, execution plan
- `07-delivery/` implementation packets by epic/ticket
- `08-quality/` strategy, test cases, QA evidence, manual-test gate artifacts
- `09-release/` readiness and release records
- `apps/` frontend applications
- `services/` backend services/workers
- `infra/deploy/` deployment-only compose assets
- `packages/` optional shared packages

## Working Rules

- Update `00-governance/project-state.yaml` after state-changing commands.
- Record approvals/rejections in `00-governance/approvals.md`.
- Record command mutations in `00-governance/command-log.md`.
- Track phase cycles in `00-governance/phases.md`.
- Respect stack lock in `00-governance/stack-lock.yaml`.
- Manual-test gate requires generated script execution and issue closure before quality approval.
- This workspace is inside the current repository; do not create a new repository during scaffolding.
- This template supports only one project workspace per repository clone; use `start next phase: <goal>` for additional requirements.
