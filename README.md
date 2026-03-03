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

The framework enforces explicit handoffs, mandatory human approvals, stack lock governance, and release deployability contracts.

## Core Guarantees

1. Command-driven workflow using a deterministic dispatcher.
2. Stack lock from the first intake command.
3. Strict role specialization and no self-approval.
4. Monorepo contract: `apps/`, `services/`, `infra/`, optional `packages/`.
5. Release readiness requires deployment evidence for:
   - `docker compose up --build -d`

## Repository Layout

- `agents/` role contracts, prompts, and checklists
- `workflow/` lifecycle state machine, command registry, and gate rules
- `templates/` reusable artifact templates and deployment templates
- `shared/` global standards, definitions, and monorepo contract
- `projects/_template/` clone-ready project workspace skeleton
- `scripts/` command engine and validation helpers
- `archive/` retention location for closed artifacts

## Command Execution Quickstart

1. Start project from intake command (stack lock initialized):
   - `./scripts/command-dispatch.sh --command "to project manager: I want to build gym erp | fe=next | be=nest | db=sqlite | cache=redis" --actor human-owner`
2. Execute governed workflow commands:
   - `./scripts/command-dispatch.sh --project gym-erp --command "review scope" --actor business-analyst`
   - `./scripts/command-dispatch.sh --project gym-erp --command "lock scope" --actor project-manager`
   - `./scripts/command-dispatch.sh --project gym-erp --command "generate epics" --actor project-manager`
3. Validate deployment readiness contract:
   - `./scripts/validate-deployability.sh projects/gym-erp`

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
8. Quality
9. Release

Every stage transition requires:

1. Required artifacts.
2. Human gate decision.
3. Updated `project-state.yaml`.
4. Command audit entry for the transition-driving command.
