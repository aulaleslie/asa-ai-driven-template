# Monorepo Contract

## Canonical Structure

Every generated project is expected to follow:

- `project/apps/` for frontend and user-facing applications
- `project/services/` for backend APIs and workers
- `project/infra/` for deployment/runtime manifests and environment contracts
- `project/packages/` for optional shared libraries

## Ownership Boundaries

- UI/UX Designer and Software Developer own `project/apps/` structure decisions.
- Solution Architect and Software Developer own `project/services/` boundaries.
- Solution Architect, SDET, and Project Manager govern `project/infra/deploy` release readiness.
- Shared contracts in `project/packages/` require architecture traceability.

## Engineering Method Baseline

- Delivery uses stack-aware TDD + DDD by default across `project/apps/` and `project/services/`.
- If selected stack requires an equivalent method, it must be documented in architecture and test strategy with approval reference.
- SDET verifies method compliance evidence before quality/release approvals.

## Deployment Contract

Deployment artifacts must be under `project/infra/deploy/` and include:

1. `docker-compose.yml`
2. `.env.example`
3. Deployment README with service map, ports, and command usage.

The release gate requires explicit evidence that deployment can be run with:

- `docker compose up --build -d`
