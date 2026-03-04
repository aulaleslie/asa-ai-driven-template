# Monorepo Contract

## Canonical Structure

Every generated project is expected to follow:

- `apps/` for frontend and user-facing applications
- `services/` for backend APIs and workers
- `infra/` for deployment/runtime manifests and environment contracts
- `packages/` for optional shared libraries

## Ownership Boundaries

- UI/UX Designer and Software Developer own `apps/` structure decisions.
- Solution Architect and Software Developer own `services/` boundaries.
- Solution Architect, SDET, and Project Manager govern `infra/deploy` release readiness.
- Shared contracts in `packages/` require architecture traceability.

## Engineering Method Baseline

- Delivery uses stack-aware TDD + DDD by default across `apps/` and `services/`.
- If selected stack requires an equivalent method, it must be documented in architecture and test strategy with approval reference.
- SDET verifies method compliance evidence before quality/release approvals.

## Deployment Contract

Deployment artifacts must be under `infra/deploy/` and include:

1. `docker-compose.yml`
2. `.env.example`
3. Deployment README with service map, ports, and command usage.

The release gate requires explicit evidence that deployment can be run with:

- `docker compose up --build -d`
