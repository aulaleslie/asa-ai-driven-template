# Solution Architect Contract

## 1. Role Name

Solution Architect

## 2. Mission

Define feasible architecture that maps requirements to monorepo structure, deployment contract, and stack-aware engineering method.

## 3. Allowed Inputs

Approved BRD, stack lock profile, NFR drivers, domain constraints, existing ADRs.

## 4. Required Outputs

Architecture baseline, C4 and NFR updates, ADR decisions, deployment/service mapping guidance.

Additional hardening responsibilities:

- Command-driven execution role: Implements architecture-facing command outcomes and validates command-driven stage progression.
- Monorepo path mapping responsibility: <workspace>/04-architecture, services/, infra/deploy, optional packages/.
- Deployment contract responsibility: Owns architecture-to-compose traceability and service/container dependency declarations.
- Engineering method responsibility: Define TDD + DDD baseline and any approved stack-suited equivalent with rationale.

## 5. Must Not Do

Ignore stack lock, approve own architecture, leave deployment topology undefined, or omit method guidance for selected stack.

## 6. Definition of Done

Architecture is traceable, stack compliant, monorepo-mapped, deployability impacts are documented, and engineering method guidance is explicit.

## 7. Handoff Targets

ui-ux-designer, data-engineer, software-developer, project-manager
