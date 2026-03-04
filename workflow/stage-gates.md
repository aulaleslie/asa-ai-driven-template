# Stage Gates

Each stage gate enforces quality, governance, and deployment readiness.

| Stage | Required Artifacts | Human Approver | Pass Criteria | Fail Criteria |
| --- | --- | --- | --- | --- |
| Intake | Request + stack lock profile | Sponsor or Product Owner | Request is clear, stack lock defined | Missing objective or invalid stack profile |
| Discovery | Charter + scope docs + open questions | Product Owner | Scope boundaries are explicit | Scope ambiguity remains high |
| Analysis | BRD + stories + rules + glossary | Product Owner + BA Lead | Requirements are testable and approved | Conflicts or missing requirements |
| Architecture | Architecture + NFR + C4 + ADR | Tech Lead/Architect Reviewer | Design is feasible and traceable | Major risks unresolved |
| Design | UX flows + wireframes + component map | Product/Design Reviewer | Core journeys and edge states complete | Key journeys missing |
| Planning | Delivery map + epics + tickets + execution plan | Delivery Manager | Work is decomposed, dependency-ordered, and actionable (timeline optional) | Work items are ambiguous |
| Delivery | Ticket packet + review report | Engineering Manager | Ticket meets DoD and review quality | Incomplete implementation evidence |
| Quality | Test strategy + acceptance cases + QA report + manual test artifacts + deployment evidence | QA Lead | Acceptance criteria pass, manual-test gate approved, open manual-test issues = 0, deployability checks pass | Critical defects, unapproved manual test gate, or open manual-test issues |
| Release | Readiness + release notes + known issues + compose manifest refs | Release Approver | `docker compose up --build -d` evidence accepted and quality manual-test gate already approved | Blocking risk, missing deployment evidence, or missing manual-test approval |

## Manual Test Gate (Inside Quality)

Quality pass requires:

1. Generated manual test runbook exists.
2. Human executes runbook and records results.
3. Manual feedback is captured.
4. Any issues follow strict lifecycle until closed.
5. Manual-test gate is explicitly approved.

## Deployment Contract Checks

Quality and Release must include:

1. Presence of `infra/deploy/docker-compose.yml`.
2. Service/container contract mapping.
3. Evidence log in `09-release/Deployment_Readiness_Evidence.md`.
4. Human sign-off that deployment command is valid for release context.

## Gate Decision Values

- `approved`: proceed.
- `rejected`: revise in same stage.
- `blocked`: external dependency prevents continuation.
