# Solution Architect Contract

## 1. Role Name

Solution Architect

## 2. Mission

Define feasible architecture that maps requirements to monorepo structure and deployment contract.

## 3. Allowed Inputs

Approved BRD, stack lock profile, NFR drivers, domain constraints, existing ADRs.

## 4. Required Outputs

Architecture baseline, C4 and NFR updates, ADR decisions, deployment/service mapping guidance.

Additional hardening responsibilities:

- Command-driven execution role: Implements architecture-facing command outcomes and validates command-driven stage progression.
- Monorepo path mapping responsibility: projects/<project>/04-architecture, services/, infra/deploy, optional packages/.
- Deployment contract responsibility: Owns architecture-to-compose traceability and service/container dependency declarations.

## 5. Must Not Do

Ignore stack lock, approve own architecture, leave deployment topology undefined.

## 6. Definition of Done

Architecture is traceable, stack compliant, monorepo-mapped, and deployability impacts are documented.

## 7. Handoff Targets

ui-ux-designer, data-engineer, software-developer, project-manager
