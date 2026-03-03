#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage:
  $(basename "$0") --command "<phrase>" [--project <slug>] --actor <actor-id>

Examples:
  $(basename "$0") --command "to project manager: I want to build gym erp | fe=next | be=nest | db=sqlite | cache=redis" --actor human-owner
  $(basename "$0") --project gym-erp --command "lock scope" --actor project-manager
USAGE
}

log() {
  printf '[command-dispatch] %s\n' "$1"
}

die() {
  log "ERROR: $1"
  exit "${2:-1}"
}

slugify() {
  local input="$1"
  echo "$input" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g' \
    | sed -E 's/^-+|-+$//g' \
    | sed -E 's/-+/-/g'
}

project_path_from_slug() {
  local slug="$1"
  if [ -z "$slug" ]; then
    echo ""
    return
  fi
  if [ -d "$slug" ]; then
    echo "$slug"
  else
    echo "projects/$slug"
  fi
}

state_value() {
  local key="$1"
  local state_file="$2"
  grep -E "^${key}:" "$state_file" | sed -E "s/^${key}:\s*//" | head -n1
}

set_state_value() {
  local state_file="$1"
  local key="$2"
  local value="$3"
  local tmp_file
  tmp_file="${state_file}.tmp"
  awk -v key="$key" -v value="$value" '
    BEGIN { updated=0 }
    $0 ~ "^" key ":" { print key ": " value; updated=1; next }
    { print }
    END { if (updated==0) print key ": " value }
  ' "$state_file" > "$tmp_file"
  mv "$tmp_file" "$state_file"
}

add_approved_artifact() {
  local state_file="$1"
  local artifact="$2"
  local current
  current="$(state_value approved_artifacts "$state_file")"
  if echo "$current" | grep -Fq "$artifact"; then
    return
  fi
  if [ "$current" = "[]" ] || [ -z "$current" ]; then
    set_state_value "$state_file" approved_artifacts "[$artifact]"
  else
    current="${current%]}"
    set_state_value "$state_file" approved_artifacts "$current, $artifact]"
  fi
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

require_project_state() {
  local project_path="$1"
  [ -d "$project_path" ] || die "project path not found: $project_path"
  [ -f "$project_path/00-governance/project-state.yaml" ] || die "project-state.yaml missing: $project_path/00-governance/project-state.yaml"
}

require_stage() {
  local expected="$1"
  local state_file="$2"
  local current
  current="$(state_value current_stage "$state_file")"
  [ "$current" = "$expected" ] || die "command requires stage '$expected' (current: $current)"
}

ensure_discovery_artifacts() {
  local project_path="$1"
  local files=(
    "$project_path/02-discovery/Project_Charter.md"
    "$project_path/02-discovery/Scope_In.md"
    "$project_path/02-discovery/Scope_Out.md"
    "$project_path/02-discovery/Open_Questions.md"
  )
  for f in "${files[@]}"; do
    [ -s "$f" ] || die "required discovery artifact missing or empty: $f"
  done
}

has_discovery_approval() {
  local project_path="$1"
  local approvals="$project_path/00-governance/approvals.md"
  [ -f "$approvals" ] || return 1
  grep -Eiq '\|[[:space:]]*discovery[[:space:]]*\|.*\|[[:space:]]*approved[[:space:]]*\|' "$approvals"
}

has_brd_approval() {
  local project_path="$1"
  local approvals="$project_path/00-governance/approvals.md"
  [ -f "$approvals" ] || return 1
  grep -Eiq '\|[[:space:]]*analysis[[:space:]]*\|.*BRD.*\|[[:space:]]*approved[[:space:]]*\|' "$approvals"
}

append_approval_entry() {
  local project_path="$1"
  local stage="$2"
  local artifacts="$3"
  local decision="$4"
  local decision_maker="$5"
  local notes="$6"
  local approvals="$project_path/00-governance/approvals.md"
  [ -f "$approvals" ] || {
    cat > "$approvals" <<APP
# Approvals Log

| Date | Stage | Artifact(s) | Decision | Decision Maker | Notes |
| --- | --- | --- | --- | --- | --- |
APP
  }
  echo "| $(date -u +%Y-%m-%d) | $stage | $artifacts | $decision | $decision_maker | $notes |" >> "$approvals"
}

validate_stack_value() {
  local label="$1"
  local value="$2"
  shift 2
  local valid=false
  for option in "$@"; do
    if [ "$value" = "$option" ]; then
      valid=true
      break
    fi
  done
  [ "$valid" = true ] || die "invalid $label stack '$value'. Allowed: $*"
}

handle_intake_start() {
  local cmd="$1"
  local actor="$2"
  local provided_project="$3"

  if [[ ! "$cmd" =~ ^to\ project\ manager:\ I\ want\ to\ build\ (.+)\ \|\ fe=([a-z0-9_-]+)\ \|\ be=([a-z0-9_-]+)\ \|\ db=([a-z0-9_-]+)\ \|\ cache=([a-z0-9_-]+)$ ]]; then
    die "invalid intake command format"
  fi

  local product_name fe be db cache slug project_path
  product_name="${BASH_REMATCH[1]}"
  fe="${BASH_REMATCH[2]}"
  be="${BASH_REMATCH[3]}"
  db="${BASH_REMATCH[4]}"
  cache="${BASH_REMATCH[5]}"

  validate_stack_value fe "$fe" next
  validate_stack_value be "$be" nest
  validate_stack_value db "$db" sqlite postgres mysql
  validate_stack_value cache "$cache" redis none

  if [ -n "$provided_project" ]; then
    slug="$provided_project"
  else
    slug="$(slugify "$product_name")"
  fi
  [ -n "$slug" ] || die "unable to derive project slug"

  project_path="$(project_path_from_slug "$slug")"

  if [ ! -d "$project_path" ]; then
    ./scripts/init-project.sh "$slug" --fe "$fe" --be "$be" --db "$db" --cache "$cache"
  fi

  require_project_state "$project_path"

  local state_file stack_file existing_lock existing_fe existing_be existing_db existing_cache
  state_file="$project_path/00-governance/project-state.yaml"
  stack_file="$project_path/00-governance/stack-lock.yaml"

  existing_lock="$(grep -E '^lock_status:' "$stack_file" | sed -E 's/^lock_status:\s*//')"
  existing_fe="$(grep -E '^fe_stack:' "$stack_file" | sed -E 's/^fe_stack:\s*//')"
  existing_be="$(grep -E '^be_stack:' "$stack_file" | sed -E 's/^be_stack:\s*//')"
  existing_db="$(grep -E '^db_stack:' "$stack_file" | sed -E 's/^db_stack:\s*//')"
  existing_cache="$(grep -E '^cache_stack:' "$stack_file" | sed -E 's/^cache_stack:\s*//')"

  if [ "$existing_lock" = "locked" ]; then
    if [ "$existing_fe" != "$fe" ] || [ "$existing_be" != "$be" ] || [ "$existing_db" != "$db" ] || [ "$existing_cache" != "$cache" ]; then
      if ! grep -Fq 'STACK_OVERRIDE_APPROVED' "$project_path/00-governance/decisions.md"; then
        die "stack is locked. add STACK_OVERRIDE_APPROVED decision entry before changing stack"
      fi
    fi
  fi

  cat > "$stack_file" <<STACK
project_name: $slug
fe_stack: $fe
be_stack: $be
db_stack: $db
cache_stack: $cache
lock_status: locked
locked_by: $actor
locked_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)
override_required: false
STACK

  set_state_value "$state_file" project_name "$slug"
  set_state_value "$state_file" stack_locked true
  set_state_value "$state_file" current_stage intake
  set_state_value "$state_file" current_item request-intake
  set_state_value "$state_file" next_actor project-manager
  set_state_value "$state_file" last_actor "$actor"
  set_state_value "$state_file" command_last intake_start

  append_command_log "$project_path" "$actor" "$cmd" success "intake initialized and stack locked"
  log "Project initialized/updated at $project_path"
}

handle_review_scope() {
  local project_path="$1"
  local actor="$2"
  local cmd="$3"
  local state_file="$project_path/00-governance/project-state.yaml"

  require_project_state "$project_path"

  local current_stage
  current_stage="$(state_value current_stage "$state_file")"
  if [ "$current_stage" = "intake" ]; then
    ./scripts/start-stage.sh "$project_path" discovery >/dev/null
  fi

  require_stage discovery "$state_file"
  set_state_value "$state_file" current_item scope-review
  set_state_value "$state_file" last_actor "$actor"
  set_state_value "$state_file" command_last review_scope

  append_command_log "$project_path" "$actor" "$cmd" success "scope review initiated"
  log "Scope review context set for $project_path"
}

handle_lock_scope() {
  local project_path="$1"
  local actor="$2"
  local cmd="$3"
  local state_file="$project_path/00-governance/project-state.yaml"

  require_project_state "$project_path"
  require_stage discovery "$state_file"
  ensure_discovery_artifacts "$project_path"
  has_discovery_approval "$project_path" || die "discovery approval not found in approvals log"

  set_state_value "$state_file" scope_locked true
  set_state_value "$state_file" current_item scope-locked
  set_state_value "$state_file" last_actor "$actor"
  set_state_value "$state_file" command_last lock_scope

  ./scripts/start-stage.sh "$project_path" analysis >/dev/null
  set_state_value "$state_file" command_last lock_scope
  set_state_value "$state_file" last_actor "$actor"

  append_command_log "$project_path" "$actor" "$cmd" success "scope locked and moved to analysis"
  log "Scope locked for $project_path"
}

handle_generate_epics() {
  local project_path="$1"
  local actor="$2"
  local cmd="$3"
  local state_file="$project_path/00-governance/project-state.yaml"

  require_project_state "$project_path"
  [ "$(state_value scope_locked "$state_file")" = "true" ] || die "scope_locked must be true"
  has_brd_approval "$project_path" || die "BRD approval not found in approvals log"

  mkdir -p "$project_path/06-planning"
  [ -f "$project_path/06-planning/Epics.md" ] || cp projects/_template/06-planning/Epics.md "$project_path/06-planning/Epics.md"
  [ -f "$project_path/06-planning/Tickets.md" ] || cp projects/_template/06-planning/Tickets.md "$project_path/06-planning/Tickets.md"
  [ -f "$project_path/06-planning/Roadmap.md" ] || cp projects/_template/06-planning/Roadmap.md "$project_path/06-planning/Roadmap.md"
  [ -f "$project_path/06-planning/Sprint_Plan.md" ] || cp projects/_template/06-planning/Sprint_Plan.md "$project_path/06-planning/Sprint_Plan.md"

  set_state_value "$state_file" current_stage planning
  set_state_value "$state_file" current_item epics
  set_state_value "$state_file" next_actor software-developer
  set_state_value "$state_file" last_actor "$actor"
  set_state_value "$state_file" command_last generate_epics

  append_command_log "$project_path" "$actor" "$cmd" success "planning artifacts prepared"
  log "Planning epics context ready for $project_path"
}

handle_start_epic() {
  local project_path="$1"
  local actor="$2"
  local cmd="$3"

  if [[ ! "$cmd" =~ ^start\ (epic-[0-9]+)$ ]]; then
    die "invalid start epic command format"
  fi

  local epic_id="${BASH_REMATCH[1]}"
  local state_file="$project_path/00-governance/project-state.yaml"

  require_project_state "$project_path"
  set_state_value "$state_file" current_stage delivery
  set_state_value "$state_file" active_epic "$epic_id"
  set_state_value "$state_file" current_item "$epic_id"
  set_state_value "$state_file" next_actor software-developer
  set_state_value "$state_file" last_actor "$actor"
  set_state_value "$state_file" command_last start_epic

  mkdir -p "$project_path/07-delivery/$epic_id"
  if [ ! -f "$project_path/07-delivery/$epic_id/epic.md" ]; then
    cp projects/_template/07-delivery/epic-1/epic.md "$project_path/07-delivery/$epic_id/epic.md"
  fi

  append_command_log "$project_path" "$actor" "$cmd" success "epic context started"
  log "Delivery context started for $epic_id"
}

handle_start_ticket() {
  local project_path="$1"
  local actor="$2"
  local cmd="$3"

  if [[ ! "$cmd" =~ ^start\ (epic-[0-9]+)-(ticket-[0-9]+)$ ]]; then
    die "invalid start ticket command format"
  fi

  local epic_id="${BASH_REMATCH[1]}"
  local ticket_id="${BASH_REMATCH[2]}"
  local state_file="$project_path/00-governance/project-state.yaml"

  require_project_state "$project_path"
  set_state_value "$state_file" current_stage delivery

  ./scripts/start-ticket.sh "$project_path" "$epic_id" "$ticket_id" >/dev/null

  set_state_value "$state_file" last_actor "$actor"
  set_state_value "$state_file" command_last start_ticket
  append_command_log "$project_path" "$actor" "$cmd" success "ticket context started"
  log "Ticket context started for $epic_id/$ticket_id"
}

handle_approve_brd() {
  local project_path="$1"
  local actor="$2"
  local cmd="$3"
  local state_file="$project_path/00-governance/project-state.yaml"
  local brd="$project_path/03-analysis/BRD.md"

  require_project_state "$project_path"
  require_stage analysis "$state_file"
  [ -s "$brd" ] || die "BRD artifact missing: $brd"

  append_approval_entry "$project_path" analysis "03-analysis/BRD.md" approved "$actor" "approved via command"
  add_approved_artifact "$state_file" BRD

  set_state_value "$state_file" current_item BRD-approved
  set_state_value "$state_file" last_actor "$actor"
  set_state_value "$state_file" command_last approve_brd

  append_command_log "$project_path" "$actor" "$cmd" success "BRD approved"
  log "BRD approval recorded"
}

handle_reject_architecture() {
  local project_path="$1"
  local actor="$2"
  local cmd="$3"
  local state_file="$project_path/00-governance/project-state.yaml"
  local arch="$project_path/04-architecture/Architecture.md"

  require_project_state "$project_path"
  require_stage architecture "$state_file"
  [ -s "$arch" ] || die "Architecture artifact missing: $arch"

  if [[ ! "$cmd" =~ ^reject\ Architecture\ with\ notes:\ (.+)$ ]]; then
    die "invalid reject architecture command format"
  fi
  local notes="${BASH_REMATCH[1]}"
  [ -n "$notes" ] || die "rejection notes are required"

  append_approval_entry "$project_path" architecture "04-architecture/Architecture.md" rejected "$actor" "$notes"
  set_state_value "$state_file" current_item architecture-rejected
  set_state_value "$state_file" status needs_rework
  set_state_value "$state_file" next_actor solution-architect
  set_state_value "$state_file" last_actor "$actor"
  set_state_value "$state_file" command_last reject_architecture

  append_command_log "$project_path" "$actor" "$cmd" success "architecture rejected with notes"
  log "Architecture rejection recorded"
}

handle_show_blockers() {
  local project_path="$1"
  local state_file="$project_path/00-governance/project-state.yaml"

  require_project_state "$project_path"
  local blockers
  blockers="$(state_value blocked_by "$state_file")"
  log "Blockers: ${blockers:-[]}" 
}

handle_resume_stage() {
  local project_path="$1"
  local actor="$2"
  local cmd="$3"
  local state_file="$project_path/00-governance/project-state.yaml"

  require_project_state "$project_path"
  local stage item next_actor status
  stage="$(state_value current_stage "$state_file")"
  item="$(state_value current_item "$state_file")"
  next_actor="$(state_value next_actor "$state_file")"
  status="$(state_value status "$state_file")"

  set_state_value "$state_file" last_actor "$actor"
  set_state_value "$state_file" command_last resume_stage
  append_command_log "$project_path" "$actor" "$cmd" success "stage resumed"

  log "Current stage: $stage"
  log "Current item: $item"
  log "Status: $status"
  log "Next actor: $next_actor"
}

handle_close_ticket() {
  local project_path="$1"
  local actor="$2"
  local cmd="$3"
  local state_file="$project_path/00-governance/project-state.yaml"

  require_project_state "$project_path"
  require_stage delivery "$state_file"

  local epic ticket ticket_dir
  epic="$(state_value active_epic "$state_file")"
  ticket="$(state_value active_ticket "$state_file")"
  [ -n "$epic" ] && [ "$epic" != "none" ] || die "active_epic not set"
  [ -n "$ticket" ] && [ "$ticket" != "none" ] || die "active_ticket not set"

  ticket_dir="$project_path/07-delivery/$epic/$ticket"
  for f in ticket.md handoff.md implementation-plan.md review-report.md; do
    [ -s "$ticket_dir/$f" ] || die "missing required delivery artifact: $ticket_dir/$f"
  done

  set_state_value "$state_file" current_item "$epic/$ticket-closed"
  set_state_value "$state_file" active_ticket none
  set_state_value "$state_file" next_actor sdet
  set_state_value "$state_file" last_actor "$actor"
  set_state_value "$state_file" command_last close_ticket

  append_command_log "$project_path" "$actor" "$cmd" success "ticket closed and handed to sdet"
  log "Ticket closed: $epic/$ticket"
}

project_slug=""
command_phrase=""
actor="system"

if [ "$#" -eq 0 ]; then
  usage
  exit 1
fi

while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --project)
      [ -n "${2:-}" ] || die "--project requires a value"
      project_slug="$2"
      shift 2
      ;;
    --command)
      [ -n "${2:-}" ] || die "--command requires a value"
      command_phrase="$2"
      shift 2
      ;;
    --actor)
      [ -n "${2:-}" ] || die "--actor requires a value"
      actor="$2"
      shift 2
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
done

[ -n "$command_phrase" ] || die "--command is required"

project_path=""
if [ -n "$project_slug" ]; then
  project_path="$(project_path_from_slug "$project_slug")"
fi

if [[ "$command_phrase" =~ ^to\ project\ manager:\ I\ want\ to\ build\ .+\ \|\ fe=.+\ \|\ be=.+\ \|\ db=.+\ \|\ cache=.+$ ]]; then
  handle_intake_start "$command_phrase" "$actor" "$project_slug"
elif [ "$command_phrase" = "review scope" ]; then
  [ -n "$project_path" ] || die "--project is required for 'review scope'"
  handle_review_scope "$project_path" "$actor" "$command_phrase"
elif [ "$command_phrase" = "lock scope" ]; then
  [ -n "$project_path" ] || die "--project is required for 'lock scope'"
  handle_lock_scope "$project_path" "$actor" "$command_phrase"
elif [ "$command_phrase" = "generate epics" ]; then
  [ -n "$project_path" ] || die "--project is required for 'generate epics'"
  handle_generate_epics "$project_path" "$actor" "$command_phrase"
elif [[ "$command_phrase" =~ ^start\ epic-[0-9]+$ ]]; then
  [ -n "$project_path" ] || die "--project is required for start epic command"
  handle_start_epic "$project_path" "$actor" "$command_phrase"
elif [[ "$command_phrase" =~ ^start\ epic-[0-9]+-ticket-[0-9]+$ ]]; then
  [ -n "$project_path" ] || die "--project is required for start ticket command"
  handle_start_ticket "$project_path" "$actor" "$command_phrase"
elif [ "$command_phrase" = "approve BRD" ]; then
  [ -n "$project_path" ] || die "--project is required for 'approve BRD'"
  handle_approve_brd "$project_path" "$actor" "$command_phrase"
elif [[ "$command_phrase" =~ ^reject\ Architecture\ with\ notes:\ .+$ ]]; then
  [ -n "$project_path" ] || die "--project is required for reject architecture command"
  handle_reject_architecture "$project_path" "$actor" "$command_phrase"
elif [ "$command_phrase" = "show blockers" ]; then
  [ -n "$project_path" ] || die "--project is required for 'show blockers'"
  handle_show_blockers "$project_path"
elif [ "$command_phrase" = "resume current stage" ]; then
  [ -n "$project_path" ] || die "--project is required for 'resume current stage'"
  handle_resume_stage "$project_path" "$actor" "$command_phrase"
elif [ "$command_phrase" = "close ticket" ]; then
  [ -n "$project_path" ] || die "--project is required for 'close ticket'"
  handle_close_ticket "$project_path" "$actor" "$command_phrase"
else
  die "unsupported command phrase. refer to workflow/commands.md"
fi
