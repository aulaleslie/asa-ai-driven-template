# Project Workspace Template

Copy this directory to `projects/<project-slug>` and execute delivery via command dispatcher.

## Folder Map

- `00-governance/` state, approvals, assumptions, decisions, stack lock, command log
- `01-intake/` intake request
- `02-discovery/` charter and scope
- `03-analysis/` requirements and glossary
- `04-architecture/` technical design and ADRs
- `05-design/` UX and component mapping
- `06-planning/` roadmap, epics, tickets, sprint plan
- `07-delivery/` implementation packets by epic/ticket
- `08-quality/` strategy, test cases, QA evidence
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
- Respect stack lock in `00-governance/stack-lock.yaml`.
- Manual-test gate requires generated script execution and issue closure before quality approval.
