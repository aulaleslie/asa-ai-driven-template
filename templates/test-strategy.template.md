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
| apps/ | | |
| services/ | | |
| infra/deploy/ | Deployment tests | |
| packages/ | Optional | |

## Deployment Impact (compose)

- Deployment test scope:
- Compose validation approach:
- Health and readiness checks:

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
## 2. Scope of Testing
## 3. Out of Scope
## 4. Test Levels and Methods
## 5. Environment and Data Strategy
## 6. Defect Management Approach
## 7. Exit Criteria

## Approval Trace

| Stage | Decision | Approver | Date | Notes |
| --- | --- | --- | --- | --- |
| Quality | Pending | | | |

## Definition of Done Checks

- [ ] Strategy aligns with project risks.
- [ ] Coverage priorities are explicit.
- [ ] Exit criteria are measurable.
- [ ] Deployability test coverage is explicit.
- [ ] Manual-test gate strategy and evidence flow are explicit.

## Sign-Off

- Prepared by:
- Reviewed by:
- Approved by:
- Date:
