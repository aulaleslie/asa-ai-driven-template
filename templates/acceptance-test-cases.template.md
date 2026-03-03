# Acceptance Test Cases Template

## Purpose

Capture acceptance-level verification mapped to requirements.

## Inputs

- Approved acceptance criteria
- Test strategy

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
| infra/deploy/ | Compose verification links | |

## Deployment Impact (compose)

- Deployment-related acceptance cases:
- Service startup/dependency checks:

## Manual Test Gate Strategy

- Which cases are human-manual mandatory:
- Human run order constraints:

## Human Execution Notes

- Manual execution instructions per case:
- Evidence capture notes:

## Issue Lifecycle Linkage (`MTI-*`)

- Issue mapping field for failed cases:
- Retest mapping procedure:

## Required Sections

| Test ID | Requirement Ref | Preconditions | Steps | Expected Result | Status | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| ATC-001 | | | | | Draft | |

## Approval Trace

| Stage | Decision | Approver | Date | Notes |
| --- | --- | --- | --- | --- |
| Quality | Pending | | | |

## Definition of Done Checks

- [ ] Each case maps to a requirement.
- [ ] Preconditions and expected results are explicit.
- [ ] Negative/edge cases are included where relevant.
- [ ] Deployment acceptance coverage is present.
- [ ] Manual-test issue linkage is documented for failures.

## Sign-Off

- Authored by:
- Reviewed by:
- Date:
