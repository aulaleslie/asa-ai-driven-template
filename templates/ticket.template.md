# Ticket Template

## Purpose

Define an implementable and testable unit of work.

## Inputs

- Approved epic
- Architecture/design references

## Command Context

- Initiating command:
- Command actor:
- Stage at creation:

## Stack Profile Reference

- Stack lock file:

## Monorepo Path Impact

| Path | Impact Type | Notes |
| --- | --- | --- |
| apps/ | | |
| services/ | | |
| infra/deploy/ | | |
| packages/ | Optional | |

## Deployment Impact (compose)

- Service/container impact:
- Environment variable impact:
- Port/runtime impact:

## Stack-Aware Implementation Method

- Default method: TDD + DDD
- Stack-specific adaptation:
- If equivalent alternative is used, reference approval:

## Domain Scope

- Domain concept(s) impacted:
- Boundary/rule changes:

## TDD Plan

- Failing tests to author/update first:
- Expected red-green-refactor loop:
- Regression tests impacted:

## Required Sections

## 1. Ticket ID and Title
## 2. Problem/Goal
## 3. Scope In / Scope Out
## 4. Implementation Constraints
## 5. Domain Scope
## 6. Stack-Aware Implementation Method
## 7. TDD Plan
## 8. Acceptance Criteria
## 9. Test Notes
## 10. Risks and Dependencies
## 11. Handoff Expectations

## Approval Trace

| Stage | Decision | Approver | Record Ref | Notes |
| --- | --- | --- | --- | --- |
| Delivery | Pending | | | |

## Definition of Done Checks

- [ ] Scope is bounded.
- [ ] Acceptance criteria are verifiable.
- [ ] Dependencies are explicit.
- [ ] Monorepo and deployment impacts are explicit.
- [ ] TDD/domain method and evidence plan are explicit.
