# Conventions

## Naming

- Use `Title_Case.md` for project-stage artifact files.
- Use lowercase with hyphens for directories and scripts.
- Use `epic-<n>` and `ticket-<n>` in delivery folders.

## Monorepo Contract

Required top-level structure for generated systems:

- `project/apps/` frontend apps and user-facing clients
- `project/services/` backend APIs/workers
- `project/infra/` deployment and operations assets
- `project/packages/` optional shared libraries/contracts

## Repository Scaffolding Rule

- Scaffold project workspaces only inside the current repository.
- Workspace target is repository root (`./`) in single-project mode.
- Do not create additional project workspaces in the same repository clone.
- Never create or initialize a new repository as part of workflow commands.

## Deployment Naming Standards

- Compose service names must be lowercase kebab-case.
- Environment variables must be uppercase snake case.
- Service ports must be explicitly documented in `project/infra/deploy/README.md`.
- Deployment-only compose files live under `project/infra/deploy/`.

## Stack-Aware Development Method

- Default engineering method is TDD + DDD.
- TDD requirement: tests are designed first (or updated first for changed behavior) and drive implementation.
- DDD requirement: domain boundaries, ubiquitous language, and domain model responsibilities are explicit.
- If a stack requires a different equivalent method, document the rationale and method in architecture + test strategy before delivery approval.

### Stack Baseline Guidance

- FE `next`: test-first component/page behavior and domain-oriented UI/application boundaries.
- BE `nest`: domain modules/bounded contexts with test-first use-case/service behavior.
- DB `sqlite|postgres|mysql`: schema/repository behavior validated with migration and persistence tests.
- Cache `redis|none`: caching and invalidation behavior must be testable and explicit (or explicitly absent for `none`).

## Versioning and Change Notes

- Record major decisions in `00-governance/decisions.md`.
- Keep ADR filenames as `ADR-###.md` with zero padding.
- Use command references and artifact versions for traceability instead of schedule dates.

## Writing Style

- Prefer concise, testable statements.
- Mark assumptions explicitly.
- Avoid vague terms without measurable criteria.
- Avoid timeline commitments in agent-authored plans unless explicitly required by human governance.
