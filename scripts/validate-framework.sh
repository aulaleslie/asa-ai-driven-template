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
  execute_ticket
  approve_brd
  reject_architecture
  prepare_manual_test
  start_manual_test
  submit_manual_test_failed
  resolve_manual_issue
  retest_manual_issue_passed
  retest_manual_issue_failed
  submit_manual_test_passed
  approve_manual_test_gate
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
  handle_execute_ticket
  handle_approve_brd
  handle_reject_architecture
  handle_prepare_manual_test
  handle_start_manual_test
  handle_submit_manual_test_failed
  handle_resolve_manual_issue
  handle_retest_manual_issue_passed
  handle_retest_manual_issue_failed
  handle_submit_manual_test_passed
  handle_approve_manual_test_gate
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

if ! grep -Fq "resolve_command_id" scripts/command-dispatch.sh; then
  log "MISSING registry-driven command resolution in command-dispatch.sh"
  missing=1
fi

for cmd_id in "${required_command_ids[@]}"; do
  registry_stage="$(
    awk -v id="$cmd_id" '
      $1 == "-" && $2 == "id:" { in_item = ($3 == id); next }
      in_item && $1 == "required_stage:" {
        $1 = ""
        sub(/^[[:space:]]+/, "", $0)
        print $0
        exit
      }
    ' workflow/command-registry.yaml
  )"
  line="$(grep -E "^\|[[:space:]]*${cmd_id}[[:space:]]*\|" workflow/commands.md | head -n1 || true)"
  if [ -z "$line" ] || [ -z "$registry_stage" ]; then
    continue
  fi
  if ! echo "$line" | grep -Fq "| $registry_stage |"; then
    log "STAGE MISMATCH for $cmd_id (expected in commands.md: '$registry_stage')"
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
  manual_test_gate_status
  manual_test_last_result
  open_manual_issues
  manual_test_script_path
)

for key in "${required_state_keys[@]}"; do
  if ! grep -Eq "^${key}:" projects/_template/00-governance/project-state.yaml; then
    log "MISSING state key in template: $key"
    missing=1
  fi
done

required_artifacts=(
  projects/_template/08-quality/Manual_Test_Script.md
  projects/_template/08-quality/Manual_Test_Execution_Log.md
  projects/_template/08-quality/Manual_Test_Feedback.md
  projects/_template/08-quality/Manual_Test_Issues.md
  scripts/generate-manual-test-script.sh
  scripts/validate-manual-test-gate.sh
)

for f in "${required_artifacts[@]}"; do
  if [ ! -f "$f" ]; then
    log "MISSING required framework artifact: $f"
    missing=1
  fi
done

if [ "$missing" -eq 0 ]; then
  log "Framework validation passed."
  exit 0
fi

log "Framework validation failed."
exit 2
