# Deployment Readiness Evidence Template

## Command Context

- Initiating command:
- Command actor:
- Stage:

## Stack Profile Reference

- Stack lock file:
- Stack summary:

## Monorepo Path Impact

| Path | Impact Type | Notes |
| --- | --- | --- |
| project/infra/deploy/ | Primary | |
| project/services/ | | |
| project/apps/ | Optional | |

## Deployment Impact (compose)

- Deployment command: `docker compose up --build -d`
- Compose file path:
- Env file path:
- Services included:

## Evidence

- Validation run date:
- Validator:
- Outcome:
- Logs/notes:

## Approval Trace

| Stage | Decision | Approver | Record Ref | Notes |
| --- | --- | --- | --- | --- |
| Quality/Release | Pending | | | |

## Definition of Done Checks

- [ ] Compose artifacts are present and referenced.
- [ ] Service mapping is complete.
- [ ] Human approver decision is recorded.
