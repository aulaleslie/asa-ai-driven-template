# Service Container Contract Template

## Command Context

- Initiating command:
- Command actor:
- Stage:

## Stack Profile Reference

- Stack lock file:

## Monorepo Path Impact

| Path | Impact Type | Notes |
| --- | --- | --- |
| services/<service> | Primary | |
| infra/deploy/docker-compose.yml | Primary | |

## Deployment Impact (compose)

- Service name:
- Build context:
- Dockerfile path:
- Port mappings:
- Required env vars:
- Healthcheck strategy:

## Required Sections

## 1. Service Identity
## 2. Runtime Contract
## 3. Build Contract
## 4. Dependency Contract
## 5. Observability/Health Contract

## Approval Trace

| Stage | Decision | Approver | Date | Notes |
| --- | --- | --- | --- | --- |
| Architecture/Quality | Pending | | | |

## Definition of Done Checks

- [ ] Runtime and build contracts are explicit.
- [ ] Dependencies and health assumptions are documented.
- [ ] Compose mapping is traceable.
