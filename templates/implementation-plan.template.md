# Implementation Plan Template

## Purpose

Describe execution approach for a ticket before implementation.
Focus on immediate implementation sequencing and checks, not calendar estimates.

## Inputs

- Ticket definition
- Architecture and design artifacts

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

- New/changed services:
- Build/runtime dependencies:
- Compose impact notes:

## Stack-Aware Engineering Method

- Default method: TDD + DDD
- Selected stack adaptation:
- If equivalent alternative is used, approval reference:

## Domain Model Change Plan

- Bounded context(s) impacted:
- Domain objects/rules changed:
- Invariant and business-rule checks:

## Test-First Sequence

- Initial failing tests:
- Green implementation steps:
- Refactor checkpoints:
- Regression suite updates:

## Required Sections

## 1. Approach Summary
## 2. Work Breakdown
## 3. Impacted Components
## 4. Domain Model Change Plan
## 5. Stack-Aware Engineering Method
## 6. Test-First Sequence
## 7. Data/Integration Changes
## 8. Validation Strategy
## 9. Rollback or Recovery Notes
## 10. Risks and Mitigations

## Approval Trace

| Stage | Decision | Approver | Record Ref | Notes |
| --- | --- | --- | --- | --- |
| Delivery | Pending | | | |

## Definition of Done Checks

- [ ] Plan is traceable to ticket acceptance criteria.
- [ ] Validation covers edge and failure modes.
- [ ] Risks are acknowledged with mitigation actions.
- [ ] Deployment and path impacts are included.
- [ ] TDD flow and domain-model impact are explicit and stack-aware.

## Sign-Off

- Prepared by:
- Reviewed by:
- Record reference:
