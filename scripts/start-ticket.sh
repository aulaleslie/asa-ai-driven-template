#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage: $(basename "$0") <project-path> <epic-id> <ticket-id>

Bootstrap delivery files for a ticket and update project state.
Example: $(basename "$0") . epic-2 ticket-5
USAGE
}

log() {
  printf '[start-ticket] %s\n' "$1"
}

die() {
  log "ERROR: $1"
  exit "${2:-1}"
}

sanitize_table_cell() {
  local value="${1:-}"
  value="$(printf '%s' "$value" | tr '\n' ' ' | sed -E 's/[[:space:]]+/ /g; s/^[[:space:]]+|[[:space:]]+$//g')"
  value="${value//|/&#124;}"
  printf '%s' "$value"
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

append_command_log() {
  local project_path="$1"
  local actor="$2"
  local command="$3"
  local result="$4"
  local notes="$5"
  local actor_cell command_cell result_cell notes_cell
  local log_file="$project_path/00-governance/command-log.md"

  actor_cell="$(sanitize_table_cell "$actor")"
  command_cell="$(sanitize_table_cell "$command")"
  result_cell="$(sanitize_table_cell "$result")"
  notes_cell="$(sanitize_table_cell "$notes")"

  [ -f "$log_file" ] || {
    cat > "$log_file" <<LOG
# Command Log

| Timestamp (UTC) | Actor | Command | Result | Notes |
| --- | --- | --- | --- | --- |
LOG
  }
  echo "| $(date -u +%Y-%m-%dT%H:%M:%SZ) | $actor_cell | $command_cell | $result_cell | $notes_cell |" >> "$log_file"
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

[ "$#" -eq 3 ] || { usage; exit 1; }

project_path="$1"
epic_id="$2"
ticket_id="$3"
state_file="$project_path/00-governance/project-state.yaml"

[ -d "$project_path" ] || die "project path not found at $project_path"
[ -f "$state_file" ] || die "state file not found at $state_file"

[[ "$epic_id" =~ ^epic-[0-9]+$ ]] || die "invalid epic id: $epic_id"
[[ "$ticket_id" =~ ^ticket-[0-9]+$ ]] || die "invalid ticket id: $ticket_id"

current_stage="$(get_state_value current_stage "$state_file")"
[ "$current_stage" = "delivery" ] || die "current stage must be delivery (found: $current_stage)"

epic_dir="$project_path/07-delivery/$epic_id"
ticket_dir="$epic_dir/$ticket_id"

template_ticket_dir="projects/_template/07-delivery/epic-1/ticket-1"
template_epic_file="projects/_template/07-delivery/epic-1/epic.md"

mkdir -p "$ticket_dir"

if [ ! -f "$epic_dir/epic.md" ]; then
  if [ -f "$template_epic_file" ]; then
    cp "$template_epic_file" "$epic_dir/epic.md"
  else
    cat > "$epic_dir/epic.md" <<EPIC
# ${epic_id}

## Objective

## Scope

## Acceptance Criteria
EPIC
  fi
fi

for f in ticket.md handoff.md implementation-plan.md task-execution-log.md review-report.md; do
  src="$template_ticket_dir/$f"
  dst="$ticket_dir/$f"
  if [ -e "$dst" ]; then
    continue
  fi
  if [ -f "$src" ]; then
    cp "$src" "$dst"
  else
    cat > "$dst" <<DOC
# ${ticket_id} - ${f}

TODO: add structured content.
DOC
  fi
done

set_state_value "$state_file" active_epic "$epic_id"
set_state_value "$state_file" active_ticket "$ticket_id"
set_state_value "$state_file" current_item "$epic_id/$ticket_id"
set_state_value "$state_file" next_actor software-developer
set_state_value "$state_file" last_actor start-ticket
set_state_value "$state_file" command_last "start-ticket:$epic_id:$ticket_id"

append_command_log "$project_path" start-ticket "start $epic_id-$ticket_id" success "ticket scaffolded"

# TODO: update planning indexes (Epics.md and Tickets.md) automatically.
log "Ticket scaffold ready at $ticket_dir"
