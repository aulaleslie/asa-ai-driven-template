# Conventions

## Naming

- Use `Title_Case.md` for project-stage artifact files.
- Use lowercase with hyphens for directories and scripts.
- Use `epic-<n>` and `ticket-<n>` in delivery folders.

## Monorepo Contract

Required top-level structure for generated systems:

- `apps/` frontend apps and user-facing clients
- `services/` backend APIs/workers
- `infra/` deployment and operations assets
- `packages/` optional shared libraries/contracts

## Repository Scaffolding Rule

- Scaffold project workspaces only inside the current repository.
- Workspace target is repository root (`./`) in single-project mode.
- Do not create additional project workspaces in the same repository clone.
- Never create or initialize a new repository as part of workflow commands.

## Deployment Naming Standards

- Compose service names must be lowercase kebab-case.
- Environment variables must be uppercase snake case.
- Service ports must be explicitly documented in `infra/deploy/README.md`.
- Deployment-only compose files live under `infra/deploy/`.

## Versioning and Change Notes

- Record major decisions in `00-governance/decisions.md`.
- Keep ADR filenames as `ADR-###.md` with zero padding.
- Use command references and artifact versions for traceability instead of schedule dates.

## Writing Style

- Prefer concise, testable statements.
- Mark assumptions explicitly.
- Avoid vague terms without measurable criteria.
- Avoid timeline commitments in agent-authored plans unless explicitly required by human governance.
