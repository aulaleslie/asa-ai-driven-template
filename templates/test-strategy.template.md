# Test Strategy Template

## Purpose

Define quality approach, test levels, manual gate execution, and coverage priorities.

## Inputs

- BRD and acceptance criteria
- Architecture and design docs
- Risk catalog

## Command Context

- Initiating command:
- Command actor:
- Stage at creation:

## Stack Profile Reference

- Stack lock file:

## Monorepo Path Impact

| Path | Impact Type | Notes |
| --- | --- | --- |
| project/apps/ | | |
| project/services/ | | |
| project/infra/deploy/ | Deployment tests | |
| project/packages/ | Optional | |

## Deployment Impact (compose)

- Deployment test scope:
- Compose validation approach:
- Health and readiness checks:

## Stack-Aware TDD/DDD Strategy

- Default method: TDD + DDD
- Stack-specific test-first adaptations:
- Domain-model verification strategy:
- If equivalent alternative is used, approval reference:

## Manual Test Gate Strategy

- Runbook generation approach:
- Human tester roles:
- Entry criteria:
- Exit criteria:

## Human Execution Notes

- Human preflight checklist:
- Test data prerequisites:
- Evidence recording instructions:

## Issue Lifecycle Linkage (`MTI-*`)

- Issue creation command:
- Resolution/retest command flow:
- Closure rules:

## Required Sections

## 1. Quality Objectives
## 2. Stack-Aware TDD/DDD Strategy
## 3. Scope of Testing
## 4. Out of Scope
## 5. Test Levels and Methods
## 6. Environment and Data Strategy
## 7. Defect Management Approach
## 8. Exit Criteria

## Approval Trace

| Stage | Decision | Approver | Record Ref | Notes |
| --- | --- | --- | --- | --- |
| Quality | Pending | | | |

## Definition of Done Checks

- [ ] Strategy aligns with project risks.
- [ ] Coverage priorities are explicit.
- [ ] Exit criteria are measurable.
- [ ] Deployability test coverage is explicit.
- [ ] Manual-test gate strategy and evidence flow are explicit.
- [ ] Stack-aware TDD/domain verification strategy is explicit.

## Sign-Off

- Prepared by:
- Reviewed by:
- Approved by:
- Record reference:
