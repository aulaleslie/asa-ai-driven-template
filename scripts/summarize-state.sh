#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage: $(basename "$0") [project-path] [--json]

Print key fields from project-state.yaml.
Examples:
  $(basename "$0")
  $(basename "$0") .
  $(basename "$0") . --json
USAGE
}

log() {
  printf '[summarize-state] %s\n' "$1"
}

die() {
  log "ERROR: $1"
  exit "${2:-1}"
}

get_value() {
  local key="$1"
  local file="$2"
  grep -E "^${key}:" "$file" | sed -E "s/^${key}:\s*//" | head -n1
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

format="text"
project_path="."

if [ "$#" -eq 0 ]; then
  :
elif [ "$#" -eq 1 ]; then
  if [ "$1" = "--json" ]; then
    format="json"
  else
    project_path="$1"
  fi
elif [ "$#" -eq 2 ]; then
  project_path="$1"
  [ "$2" = "--json" ] || { usage; exit 1; }
  format="json"
else
  usage
  exit 1
fi

state_file="$project_path/00-governance/project-state.yaml"
[ -f "$state_file" ] || die "state file not found at $state_file"

keys=(
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

if [ "$format" = "json" ]; then
  printf '{\n'
  last_index=$((${#keys[@]} - 1))
  for i in "${!keys[@]}"; do
    key="${keys[$i]}"
    value="$(get_value "$key" "$state_file")"
    escaped_value=$(printf '%s' "$value" | sed 's/"/\\"/g')
    if [ "$i" -eq "$last_index" ]; then
      printf '  "%s": "%s"\n' "$key" "$escaped_value"
    else
      printf '  "%s": "%s",\n' "$key" "$escaped_value"
    fi
  done
  printf '}\n'
  exit 0
fi

log "State summary for $project_path"
for key in "${keys[@]}"; do
  value="$(get_value "$key" "$state_file")"
  printf '%-24s %s\n' "$key:" "${value:-<missing>}"
done

# TODO: include derived status checks (for example missing approvals or artifact drift).
