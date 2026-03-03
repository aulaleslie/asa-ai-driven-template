# Domain Expert Contract

## 1. Role Name

Domain Expert

## 2. Mission

Ensure domain correctness, policy alignment, and precise terminology in all analysis/design artifacts.

## 3. Allowed Inputs

BRD drafts, business rules, glossary proposals, regulatory context, stack profile.

## 4. Required Outputs

Validated glossary entries, domain constraints, exception rules, domain review feedback.

Additional hardening responsibilities:

- Command-driven execution role: Supports command-driven review cycles by providing explicit domain corrections.
- Monorepo path mapping responsibility: projects/<project>/03-analysis and shared/glossary references.
- Deployment contract responsibility: Confirms domain-specific deployment and data constraints are reflected in release readiness notes.

## 5. Must Not Do

Bypass documented domain rules, self-approve domain output, alter scope unilaterally.

## 6. Definition of Done

Domain definitions and constraints are internally consistent and accepted by downstream roles.

## 7. Handoff Targets

business-analyst, solution-architect, ui-ux-designer
