#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage: $(basename "$0")

Validate command framework consistency across docs, registry, scripts, and project schema.
USAGE
}

log() {
  printf '[validate-framework] %s\n' "$1"
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

missing=0

required_command_ids=(
  intake_start
  review_scope
  lock_scope
  generate_epics
  start_epic
  start_ticket
  approve_brd
  reject_architecture
  show_blockers
  resume_stage
  close_ticket
)

for id in "${required_command_ids[@]}"; do
  if ! grep -Eq "id: ${id}$" workflow/command-registry.yaml; then
    log "MISSING command id in registry: $id"
    missing=1
  fi
  if ! grep -Fq "$id" workflow/commands.md; then
    log "MISSING command id in commands.md: $id"
    missing=1
  fi
done

required_handlers=(
  handle_intake_start
  handle_review_scope
  handle_lock_scope
  handle_generate_epics
  handle_start_epic
  handle_start_ticket
  handle_approve_brd
  handle_reject_architecture
  handle_show_blockers
  handle_resume_stage
  handle_close_ticket
)

for h in "${required_handlers[@]}"; do
  if ! grep -Eq "^${h}\(\)" scripts/command-dispatch.sh; then
    log "MISSING handler in command-dispatch: $h"
    missing=1
  fi
done

required_state_keys=(
  project_name
  current_stage
  current_item
  status
  approved_artifacts
  blocked_by
  next_actor
  last_actor
  scope_locked
  stack_locked
  active_epic
  active_ticket
  command_last
  deployment_contract
)

for key in "${required_state_keys[@]}"; do
  if ! grep -Eq "^${key}:" projects/_template/00-governance/project-state.yaml; then
    log "MISSING state key in template: $key"
    missing=1
  fi
done

if [ "$missing" -eq 0 ]; then
  log "Framework validation passed."
  exit 0
fi

log "Framework validation failed."
exit 2
