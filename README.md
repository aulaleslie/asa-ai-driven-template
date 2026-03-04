# agent-delivery-system

A document-first, command-executable, multi-agent software delivery framework for human-supervised monorepo projects.

## Purpose

This repository is an operating system for specialized delivery agents:

- Project Manager
- Business Analyst
- Domain Expert
- Solution Architect
- UI/UX Designer
- Data Engineer
- SDET
- Software Developer

The framework enforces explicit handoffs, mandatory human approvals, stack lock governance, manual quality gates, and release deployability contracts.

## Core Guarantees

1. Command-driven workflow using a deterministic dispatcher.
2. Stack lock from the first intake command.
3. Strict role specialization and no self-approval.
4. Monorepo contract: `apps/`, `services/`, `infra/`, optional `packages/`.
5. Quality gate includes mandatory human manual-test execution using generated runbook.
6. Release readiness requires deployment evidence for:
   - `docker compose up --build -d`
7. Scaffolding is always in-place in the current repository (no new repository creation).
8. Planning is execution-sequencing only; timeline/date estimation is not required unless a human explicitly asks.

## Repository Layout

- `agents/` role contracts, prompts, and checklists
- `workflow/` lifecycle state machine, command registry, and gate rules
- `templates/` reusable artifact templates and deployment/manual-test templates
- `shared/` global standards, definitions, and monorepo contract
- `projects/_template/` clone-ready project workspace skeleton
- `scripts/` command engine and validation helpers
- `archive/` retention location for closed artifacts

## Command Execution Quickstart

1. Start project from intake command (stack lock initialized):
   - `./scripts/command-dispatch.sh --command "to project manager: I want to build gym erp | fe=next | be=nest | db=sqlite | cache=redis" --actor human-owner`
2. Approve and move through stage gates (single command entry point):
   - `./scripts/command-dispatch.sh --command "preflight" --actor project-manager`
   - `./scripts/command-dispatch.sh --command "approve stage intake" --actor sponsor`
   - `./scripts/command-dispatch.sh --command "advance stage" --actor project-manager`
   - `./scripts/command-dispatch.sh --command "review scope" --actor business-analyst`
   - `./scripts/command-dispatch.sh --command "approve stage discovery" --actor product-owner`
   - `./scripts/command-dispatch.sh --command "lock scope" --actor project-manager`
   - `./scripts/command-dispatch.sh --command "approve BRD" --actor product-owner`
   - `./scripts/command-dispatch.sh --command "approve stage analysis" --actor product-owner`
   - `./scripts/command-dispatch.sh --command "advance stage" --actor project-manager`
   - `./scripts/command-dispatch.sh --command "generate epics" --actor project-manager`
   - `./scripts/command-dispatch.sh --command "approve stage planning" --actor delivery-manager`
3. Move into delivery execution:
   - `./scripts/command-dispatch.sh --command "start epic-1" --actor project-manager`
   - `./scripts/command-dispatch.sh --command "start epic-1-ticket-1" --actor software-developer`
   - `./scripts/command-dispatch.sh --command "execute current ticket" --actor software-developer`
   - `./scripts/command-dispatch.sh --command "close ticket" --actor software-developer`
4. Run manual-test gate inside quality stage:
   - `./scripts/command-dispatch.sh --command "prepare manual test" --actor sdet`
   - `./scripts/command-dispatch.sh --command "submit manual test failed: login flow broken | severity=high | details=login button returns 500" --actor human-tester`
   - `./scripts/command-dispatch.sh --command "resolve manual issue MTI-001 with notes: fixed API route mismatch" --actor software-developer`
   - `./scripts/command-dispatch.sh --command "retest manual issue MTI-001 passed" --actor human-tester`
   - `./scripts/command-dispatch.sh --command "approve manual test gate" --actor qa-lead`
   - `./scripts/command-dispatch.sh --command "approve stage quality" --actor qa-lead`
5. Validate gates:
   - `./scripts/validate-manual-test-gate.sh .`
   - `./scripts/validate-deployability.sh .`

## Scaffolding Behavior

- This template is used inside an already created repository.
- Commands scaffold project workspaces in repository root by default.
- `--project` remains available for legacy or multi-workspace usage under `projects/`.
- The framework never creates or initializes a separate repository.

## Policy: Development vs Deployment

- Development environment setup is human-managed and project-specific.
- Docker Compose is a deployment contract only.
- The framework requires release evidence that deployment can be executed with:
  - `docker compose up --build -d`

## Lifecycle

1. Intake
2. Discovery
3. Analysis
4. Architecture
5. Design
6. Planning
7. Delivery
8. Quality (includes human manual-test gate)
9. Release

Every stage transition requires:

1. Required artifacts.
2. Human gate decision.
3. Updated `project-state.yaml`.
4. Command audit entry for the transition-driving command.
