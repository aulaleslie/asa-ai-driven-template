# Stage Gates

Each stage gate enforces quality, governance, and deployment readiness.

| Stage | Required Artifacts | Human Approver | Pass Criteria | Fail Criteria |
| --- | --- | --- | --- | --- |
| Intake | Request + stack lock profile | Sponsor or Product Owner | Request is clear, stack lock defined | Missing objective or invalid stack profile |
| Discovery | Charter + scope docs + open questions | Product Owner | Scope boundaries are explicit | Scope ambiguity remains high |
| Analysis | BRD + stories + rules + glossary | Product Owner + BA Lead | Requirements are testable and approved | Conflicts or missing requirements |
| Architecture | Architecture + NFR + C4 + ADR | Tech Lead/Architect Reviewer | Design is feasible and traceable | Major risks unresolved |
| Design | UX flows + wireframes + component map | Product/Design Reviewer | Core journeys and edge states complete | Key journeys missing |
| Planning | Roadmap + epics + tickets + sprint plan | Delivery Manager | Plan is sequenced and estimable | Work items are ambiguous |
| Delivery | Ticket packet + review report | Engineering Manager | Ticket meets DoD and review quality | Incomplete implementation evidence |
| Quality | Test strategy + acceptance cases + QA report + deployment evidence | QA Lead | Acceptance criteria pass and deployability checks pass | Critical defects or deployability gaps |
| Release | Readiness + release notes + known issues + compose manifest refs | Release Approver | `docker compose up --build -d` evidence accepted | Blocking risk, missing deployment evidence |

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
