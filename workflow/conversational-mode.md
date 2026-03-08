# Conversational Mode (AI-Driven)

This template supports a human-only chat interface where the AI executes dispatcher commands on behalf of the human.

## Operating Rule

- Human does not run shell commands.
- AI translates natural-language intent into `scripts/command-dispatch.sh` commands.
- AI is not constrained to exact command phrases; dispatcher canonicalizes free-form intent.
- AI reports stage, current item, blockers, and next required command after each state change.

## Phase 0 Loop

Goal: lock stack + capture multi-phase roadmap before delivery stages begin.

1. Human says they want to create a project.
2. AI asks clarifying questions (domain, stack, constraints, quality needs, phase roadmap).
3. AI executes intake:
   - `to project manager: I want to build <name> | fe=<fe> | be=<be> | db=<db> | cache=<cache>`
4. AI captures planned future phases:
   - `set phase plan: <phase-2-goal>; <phase-3-goal>; ...`
5. AI summarizes and asks human to proceed with phase-1.

Artifacts produced:

- `01-intake/request.md`
- `01-intake/Phase_0_Plan.md`
- `00-governance/stack-lock.yaml`
- `00-governance/phases.md`
- `project/` runtime scaffold (`project/apps`, `project/services`, `project/infra`, `project/packages`)

## Human Progress Commands

- Start/resume current phase: `execute phase <current>`
- Move to next planned phase after release approval: `execute phase <next>`
- Alias: `proceed phase <n>`
- Fallback for ad-hoc next phase goals: `start next phase: <goal>`
