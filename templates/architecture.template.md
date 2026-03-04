# Architecture Template

## Purpose

Describe technical design that satisfies functional and non-functional requirements.

## Inputs

- Approved BRD
- NFR drivers
- Constraints and assumptions

## Command Context

- Initiating command:
- Command actor:
- Stage at creation:

## Stack Profile Reference

- Stack lock file:
- FE/BE/DB/Cache profile:
- Override status:

## Monorepo Path Impact

| Path | Impact Type | Notes |
| --- | --- | --- |
| apps/ | | |
| services/ | | |
| infra/deploy/ | | |
| packages/ | Optional | |

## Deployment Impact (compose)

- Service graph:
- Required containers:
- Networking/ports:
- Environment contracts:

## Stack-Aware Development Method

- Default method: TDD + DDD
- Selected stack-specific method notes:
- If not pure TDD/DDD, approved equivalent and rationale:

## Domain Model and Boundaries

- Bounded contexts:
- Aggregates/entities/value objects:
- Ubiquitous language references:

## Required Sections

## 1. Architecture Overview
## 2. Context and Container View
## 3. Component View
## 4. Data Flow Overview
## 5. Integration Points
## 6. NFR Strategy
## 7. Security and Compliance Considerations
## 8. Operational Considerations
## 9. Stack-Aware Development Method
## 10. Domain Model and Boundaries
## 11. Risks and Tradeoffs
## 12. ADR References

## Approval Trace

| Stage | Decision | Approver | Record Ref | Notes |
| --- | --- | --- | --- | --- |
| Architecture | Pending | | | |

## Definition of Done Checks

- [ ] Requirements traceability is explicit.
- [ ] Major tradeoffs are documented.
- [ ] Risks have mitigation direction.
- [ ] Architecture-to-compose mapping is explicit.
- [ ] Stack-aware TDD/DDD (or approved equivalent) is explicitly documented.

## Sign-Off

- Authored by:
- Reviewed by:
- Approved by:
- Record reference:
