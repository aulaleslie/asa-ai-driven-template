# Data Model Template

## Purpose

Define entities, relationships, constraints, and ownership.

## Inputs

- BRD and business rules
- Domain glossary
- Architecture constraints

## Command Context

- Initiating command:
- Command actor:
- Stage at creation:

## Stack Profile Reference

- Stack lock file:
- DB/cache stack assumptions:

## Monorepo Path Impact

| Path | Impact Type | Notes |
| --- | --- | --- |
| project/services/ | Primary | |
| project/infra/deploy/ | Env and service dependencies | |
| project/packages/ | Shared data contracts | |

## Deployment Impact (compose)

- Database service impact:
- Cache service impact:
- Persistence and env requirements:

## Required Sections

## 1. Entity Catalog
## 2. Relationship Map
## 3. Field-Level Definitions
## 4. Validation Rules
## 5. Data Quality Controls
## 6. Data Ownership and Stewardship
## 7. Migration/Backfill Considerations

## Approval Trace

| Stage | Decision | Approver | Record Ref | Notes |
| --- | --- | --- | --- | --- |
| Architecture | Pending | | | |

## Definition of Done Checks

- [ ] Entity definitions are unambiguous.
- [ ] Validation rules are testable.
- [ ] Ownership is assigned for critical datasets.
- [ ] Deployment dependency impact is explicit.

## Sign-Off

- Authored by:
- Reviewed by:
- Approved by:
- Record reference:
