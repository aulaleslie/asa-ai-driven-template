#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage: $(basename "$0") <project-path> <stage>

Start or resume a stage by updating project-state.yaml with transition guards.
Example: $(basename "$0") projects/gym-erp analysis
USAGE
}

log() {
  printf '[start-stage] %s\n' "$1"
}

die() {
  log "ERROR: $1"
  exit "${2:-1}"
}

get_state_value() {
  local key="$1"
  local file="$2"
  grep -E "^${key}:" "$file" | sed -E "s/^${key}:\s*//" | head -n1
}

set_state_value() {
  local file="$1"
  local key="$2"
  local value="$3"
  local tmp_file
  tmp_file="${file}.tmp"
  awk -v key="$key" -v value="$value" '
    BEGIN { updated=0 }
    $0 ~ "^" key ":" { print key ": " value; updated=1; next }
    { print }
    END { if (updated==0) print key ": " value }
  ' "$file" > "$tmp_file"
  mv "$tmp_file" "$file"
}

get_next_actor_from_workflow() {
  local stage="$1"
  awk -v target="$stage" '
    $0 ~ "^    " target ":$" { in_stage=1; next }
    in_stage && $0 ~ /^      next_responsible_role:/ {
      sub(/^      next_responsible_role:[[:space:]]*/, "", $0)
      print $0
      exit
    }
    in_stage && $0 ~ /^    [a-z]/ { in_stage=0 }
  ' workflow/workflow.yaml
}

get_allowed_transitions() {
  local current_stage="$1"
  awk -v current="$current_stage" '
    /^  allowed_transitions:/ { in_transitions=1; next }
    in_transitions && /^  [a-z_]+:/ { in_transitions=0 }
    in_transitions && $1 == current ":" {
      line=$0
      sub(/^[[:space:]]*[^:]+:[[:space:]]*\[/, "", line)
      sub(/\][[:space:]]*$/, "", line)
      gsub(/[[:space:]]+/, "", line)
      print line
      exit
    }
  ' workflow/workflow.yaml
}

append_command_log() {
  local project_path="$1"
  local actor="$2"
  local command="$3"
  local result="$4"
  local notes="$5"
  local log_file="$project_path/00-governance/command-log.md"
  [ -f "$log_file" ] || {
    cat > "$log_file" <<LOG
# Command Log

| Timestamp (UTC) | Actor | Command | Result | Notes |
| --- | --- | --- | --- | --- |
LOG
  }
  echo "| $(date -u +%Y-%m-%dT%H:%M:%SZ) | $actor | $command | $result | $notes |" >> "$log_file"
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

[ "$#" -eq 2 ] || { usage; exit 1; }

project_path="$1"
target_stage="$2"
state_file="$project_path/00-governance/project-state.yaml"

[ -f "$state_file" ] || die "state file not found at $state_file"

valid=false
for s in intake discovery analysis architecture design planning delivery quality release blocked cancelled released; do
  if [ "$target_stage" = "$s" ]; then
    valid=true
    break
  fi
done
[ "$valid" = true ] || die "invalid stage '$target_stage'"

current_stage="$(get_state_value current_stage "$state_file")"
[ -n "$current_stage" ] || die "current_stage missing in state file"

if [ "$current_stage" != "$target_stage" ]; then
  allowed_csv="$(get_allowed_transitions "$current_stage")"
  [ -n "$allowed_csv" ] || die "unable to resolve transitions for stage '$current_stage'"
  is_allowed=false
  IFS=',' read -r -a allowed <<< "$allowed_csv"
  for candidate in "${allowed[@]}"; do
    if [ "$candidate" = "$target_stage" ]; then
      is_allowed=true
      break
    fi
  done
  [ "$is_allowed" = true ] || die "transition '$current_stage' -> '$target_stage' is not allowed"
fi

if [ "$target_stage" = "blocked" ] || [ "$target_stage" = "cancelled" ] || [ "$target_stage" = "released" ]; then
  set_state_value "$state_file" status "$target_stage"
  set_state_value "$state_file" last_actor stage-controller
  set_state_value "$state_file" command_last "start-stage:$target_stage"
  append_command_log "$project_path" stage-controller "start-stage $target_stage" success "status updated"
  log "Lifecycle status set to '$target_stage'"
  exit 0
fi

next_actor="$(get_next_actor_from_workflow "$target_stage")"
[ -n "$next_actor" ] || next_actor="project-manager"

set_state_value "$state_file" current_stage "$target_stage"
set_state_value "$state_file" current_item "stage-$target_stage"
set_state_value "$state_file" status in_progress
set_state_value "$state_file" next_actor "$next_actor"
set_state_value "$state_file" last_actor stage-controller
set_state_value "$state_file" command_last "start-stage:$target_stage"

append_command_log "$project_path" stage-controller "start-stage $target_stage" success "stage started"

# TODO: enforce stage invariant checks directly from workflow/workflow.yaml.
log "Stage '$target_stage' started for project at $project_path"
