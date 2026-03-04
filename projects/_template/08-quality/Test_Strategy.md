# Test Strategy

## Command Context

- Initiating command:
- Actor:

## Quality Objectives

## Test Scope

## Test Levels

## Stack-Aware TDD/DDD Strategy

- Default method: TDD + DDD
- Selected stack adaptation:
- Domain-model verification approach:
- Equivalent method approval reference (if used):

## Deployability Validation Scope

- Compose command validation:
- Service health assumptions:

## Manual Test Gate Strategy

- Runbook generation command: `prepare manual test`
- Human execution owner:
- Pass criteria:
  - `manual_test_gate_status=approved`
  - `open_manual_issues=0`

## Human Execution Notes

- Run script in `Manual_Test_Script.md`.
- Record each test run in `Manual_Test_Execution_Log.md`.

## Issue Lifecycle Linkage (`MTI-*`)

- Failure report command: `submit manual test failed: ...`
- Fix command: `resolve manual issue MTI-<n> with notes: ...`
- Retest commands:
  - `retest manual issue MTI-<n> passed`
  - `retest manual issue MTI-<n> failed: ...`

## Entry/Exit Criteria

## Defect Handling
