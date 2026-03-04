#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage:
  $(basename "$0") --command "<phrase>" [--project <slug>] --actor <actor-id>

Examples:
  $(basename "$0") --command "to project manager: I want to build gym erp | fe=next | be=nest | db=sqlite | cache=redis" --actor human-owner
  $(basename "$0") --project gym-erp --command "lock scope" --actor project-manager
  $(basename "$0") --project gym-erp --command "execute current ticket" --actor software-developer
  $(basename "$0") --project gym-erp --command "prepare manual test" --actor sdet
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

| Record Ref | Stage | Artifact(s) | Decision | Decision Maker | Notes |
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

manual_issues_file() {
  local project_path="$1"
  echo "$project_path/08-quality/Manual_Test_Issues.md"
}

manual_feedback_file() {
  local project_path="$1"
  echo "$project_path/08-quality/Manual_Test_Feedback.md"
}

manual_execution_file() {
  local project_path="$1"
  echo "$project_path/08-quality/Manual_Test_Execution_Log.md"
}

manual_script_file() {
  local project_path="$1"
  echo "$project_path/08-quality/Manual_Test_Script.md"
}

ensure_manual_quality_files() {
  local project_path="$1"
  mkdir -p "$project_path/08-quality"

  local issues_file feedback_file execution_file script_file
  issues_file="$(manual_issues_file "$project_path")"
  feedback_file="$(manual_feedback_file "$project_path")"
  execution_file="$(manual_execution_file "$project_path")"
  script_file="$(manual_script_file "$project_path")"

  [ -f "$issues_file" ] || cat > "$issues_file" <<ISS
# Manual Test Issues

| Issue ID | Source Test ID | Title | Severity | Status | Reported By | Owner | Resolution Notes | Retest Result | Updated At |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
ISS

  [ -f "$feedback_file" ] || cat > "$feedback_file" <<FDB
# Manual Test Feedback

| Timestamp (UTC) | Actor | Source Test ID | Summary | Linked Issue ID | Notes |
| --- | --- | --- | --- | --- | --- |
FDB

  [ -f "$execution_file" ] || cat > "$execution_file" <<EXE
# Manual Test Execution Log

| Timestamp (UTC) | Actor | Test ID | Result (pass/fail) | Linked Issue ID | Notes |
| --- | --- | --- | --- | --- | --- |
EXE

  [ -f "$script_file" ] || cat > "$script_file" <<SCR
# Manual Test Script

## Command Context

- Generated by command: `prepare manual test`
- Actor:
- Generated at (UTC):

## Preflight

- [ ] Access required environments
- [ ] Test data prepared
- [ ] Services available

## Ordered Test Steps

| Order | Test ID | Scenario | Steps | Expected Result |
| --- | --- | --- | --- | --- |
SCR
}

manual_gate_artifacts_present() {
  local project_path="$1"
  local files=(
    "$project_path/08-quality/Manual_Test_Script.md"
    "$project_path/08-quality/Manual_Test_Execution_Log.md"
    "$project_path/08-quality/Manual_Test_Feedback.md"
    "$project_path/08-quality/Manual_Test_Issues.md"
  )
  for f in "${files[@]}"; do
    [ -f "$f" ] || return 1
  done
  return 0
}

next_manual_issue_id() {
  local issues_file="$1"
  local max
  max="$(awk -F'|' '
    function trim(s){ gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
    /^\|/ {
      issue=trim($2)
      if (issue ~ /^MTI-[0-9]+$/) {
        n=issue
        sub(/^MTI-/, "", n)
        if ((n+0) > m) m=n+0
      }
    }
    END { print m+0 }
  ' "$issues_file")"
  printf 'MTI-%03d\n' $((max + 1))
}

manual_issue_record() {
  local issues_file="$1"
  local issue_id="$2"
  awk -F'|' -v id="$issue_id" '
    function trim(s){ gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
    /^\|/ {
      issue=trim($2)
      if (issue==id) {
        printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", trim($3), trim($4), trim($5), trim($6), trim($7), trim($8), trim($9), trim($10), trim($11)
        found=1
        exit
      }
    }
    END { if (!found) exit 1 }
  ' "$issues_file"
}

manual_issue_status() {
  local issues_file="$1"
  local issue_id="$2"
  manual_issue_record "$issues_file" "$issue_id" | awk -F'\t' '{print $4}'
}

manual_issue_exists() {
  local issues_file="$1"
  local issue_id="$2"
  manual_issue_record "$issues_file" "$issue_id" >/dev/null 2>&1
}

update_manual_issue_row() {
  local issues_file="$1"
  local issue_id="$2"
  local source_test_id="$3"
  local title="$4"
  local severity="$5"
  local status="$6"
  local reported_by="$7"
  local owner="$8"
  local resolution_notes="$9"
  local retest_result="${10}"
  local updated_at="${11}"

  local tmp_file
  tmp_file="${issues_file}.tmp"

  awk -F'|' \
    -v id="$issue_id" \
    -v source_test_id="$source_test_id" \
    -v title="$title" \
    -v severity="$severity" \
    -v status="$status" \
    -v reported_by="$reported_by" \
    -v owner="$owner" \
    -v resolution_notes="$resolution_notes" \
    -v retest_result="$retest_result" \
    -v updated_at="$updated_at" '
    function trim(s){ gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
    {
      if ($0 !~ /^\|/) {
        print $0
        next
      }

      issue=trim($2)
      if (issue=="Issue ID" || issue=="---" || issue=="") {
        print $0
        next
      }

      if (issue==id) {
        printf "| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |\n", id, source_test_id, title, severity, status, reported_by, owner, resolution_notes, retest_result, updated_at
        updated=1
        next
      }

      print $0
    }
    END {
      if (!updated) exit 7
    }
  ' "$issues_file" > "$tmp_file" || {
    rm -f "$tmp_file"
    die "failed to update issue row: $issue_id"
  }

  mv "$tmp_file" "$issues_file"
}

count_open_manual_issues() {
  local issues_file="$1"
  awk -F'|' '
    function trim(s){ gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
    /^\|/ {
      issue=trim($2)
      status=trim($6)
      if (issue=="Issue ID" || issue=="---" || issue=="") next
      if (status!="closed") c++
    }
    END { print c+0 }
  ' "$issues_file"
}

reconcile_open_manual_issues() {
  local state_file="$1"
  local issues_file="$2"
  local count
  count="$(count_open_manual_issues "$issues_file")"
  set_state_value "$state_file" open_manual_issues "$count"
}

append_manual_feedback() {
  local feedback_file="$1"
  local actor="$2"
  local source_test_id="$3"
  local summary="$4"
  local linked_issue_id="$5"
  local notes="$6"
  echo "| $(date -u +%Y-%m-%dT%H:%M:%SZ) | $actor | $source_test_id | $summary | $linked_issue_id | $notes |" >> "$feedback_file"
}

append_manual_execution() {
  local execution_file="$1"
  local actor="$2"
  local test_id="$3"
  local result="$4"
  local linked_issue_id="$5"
  local notes="$6"
  echo "| $(date -u +%Y-%m-%dT%H:%M:%SZ) | $actor | $test_id | $result | $linked_issue_id | $notes |" >> "$execution_file"
}

validate_severity() {
  local severity="$1"
  case "$severity" in
    critical|high|medium|low) return 0 ;;
    *) return 1 ;;
  esac
}

registry_path="workflow/command-registry.yaml"

registry_field() {
  local command_id="$1"
  local field="$2"
  awk -v id="$command_id" -v field="$field" '
    function strip_quotes(v) {
      sub(/^'\''/, "", v)
      sub(/'\''$/, "", v)
      return v
    }
    $1 == "-" && $2 == "id:" {
      in_item = ($3 == id)
      next
    }
    in_item && $1 == field ":" {
      $1 = ""
      sub(/^[[:space:]]+/, "", $0)
      print strip_quotes($0)
      exit
    }
  ' "$registry_path"
}

resolve_command_id() {
  local phrase="$1"
  local id pattern

  while IFS=$'\t' read -r id pattern; do
    if [[ "$phrase" =~ $pattern ]]; then
      echo "$id"
      return 0
    fi
  done < <(
    awk '
      function strip_quotes(v) {
        sub(/^'\''/, "", v)
        sub(/'\''$/, "", v)
        return v
      }
      $1 == "-" && $2 == "id:" {
        id = $3
        next
      }
      $1 == "pattern:" && id != "" {
        $1 = ""
        sub(/^[[:space:]]+/, "", $0)
        print id "\t" strip_quotes($0)
        id = ""
      }
    ' "$registry_path"
  )

  return 1
}

enforce_registry_stage() {
  local command_id="$1"
  local state_file="$2"
  local required current trimmed
  local matched=false

  required="$(registry_field "$command_id" required_stage)"
  [ -n "$required" ] || die "required_stage missing for command id: $command_id"

  case "$required" in
    none|any) return 0 ;;
  esac

  current="$(state_value current_stage "$state_file")"
  IFS=',' read -r -a allowed <<< "$required"
  for candidate in "${allowed[@]}"; do
    trimmed="$(echo "$candidate" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"
    if [ "$current" = "$trimmed" ]; then
      matched=true
      break
    fi
  done

  [ "$matched" = true ] || die "command '$command_id' requires stage '$required' (current: $current)"
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

handle_execute_ticket() {
  local project_path="$1"
  local actor="$2"
  local cmd="$3"
  local state_file="$project_path/00-governance/project-state.yaml"
  local epic ticket ticket_dir

  require_project_state "$project_path"
  require_stage delivery "$state_file"

  epic="$(state_value active_epic "$state_file")"
  ticket="$(state_value active_ticket "$state_file")"
  [ -n "$epic" ] && [ "$epic" != "none" ] || die "active_epic not set"
  [ -n "$ticket" ] && [ "$ticket" != "none" ] || die "active_ticket not set"

  ticket_dir="$project_path/07-delivery/$epic/$ticket"
  [ -d "$ticket_dir" ] || die "active ticket directory missing: $ticket_dir"

  set_state_value "$state_file" current_item "$epic/$ticket-execution"
  set_state_value "$state_file" status in_progress
  set_state_value "$state_file" next_actor software-developer
  set_state_value "$state_file" last_actor "$actor"
  set_state_value "$state_file" command_last execute_ticket

  append_command_log "$project_path" "$actor" "$cmd" success "ticket execution in progress"
  log "Execution started for $epic/$ticket"
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

handle_prepare_manual_test() {
  local project_path="$1"
  local actor="$2"
  local cmd="$3"
  local state_file="$project_path/00-governance/project-state.yaml"
  local acceptance_file="$project_path/08-quality/Acceptance_Test_Cases.md"

  require_project_state "$project_path"
  require_stage quality "$state_file"
  [ -s "$acceptance_file" ] || die "missing acceptance test cases: $acceptance_file"

  ensure_manual_quality_files "$project_path"
  ./scripts/generate-manual-test-script.sh "$project_path" >/dev/null

  set_state_value "$state_file" manual_test_gate_status prepared
  set_state_value "$state_file" manual_test_script_path 08-quality/Manual_Test_Script.md
  set_state_value "$state_file" manual_test_last_result none
  set_state_value "$state_file" last_actor "$actor"
  set_state_value "$state_file" next_actor human-tester
  set_state_value "$state_file" command_last prepare_manual_test

  append_command_log "$project_path" "$actor" "$cmd" success "manual test runbook prepared"
  log "Manual test runbook prepared"
}

handle_start_manual_test() {
  local project_path="$1"
  local actor="$2"
  local cmd="$3"
  local state_file="$project_path/00-governance/project-state.yaml"
  local status

  require_project_state "$project_path"
  require_stage quality "$state_file"
  ensure_manual_quality_files "$project_path"

  status="$(state_value manual_test_gate_status "$state_file")"
  [ "$status" = "prepared" ] || die "manual_test_gate_status must be prepared (current: $status)"

  set_state_value "$state_file" manual_test_gate_status in_progress
  set_state_value "$state_file" last_actor "$actor"
  set_state_value "$state_file" next_actor human-tester
  set_state_value "$state_file" command_last start_manual_test

  append_command_log "$project_path" "$actor" "$cmd" success "manual testing started"
  log "Manual testing started"
}

handle_submit_manual_test_failed() {
  local project_path="$1"
  local actor="$2"
  local cmd="$3"
  local state_file="$project_path/00-governance/project-state.yaml"

  require_project_state "$project_path"
  require_stage quality "$state_file"
  ensure_manual_quality_files "$project_path"

  if [[ ! "$cmd" =~ ^submit\ manual\ test\ failed:\ (.+)\ \|\ severity=(critical|high|medium|low)\ \|\ details=(.+)$ ]]; then
    die "invalid manual test failed command format"
  fi

  local title severity details gate_status
  title="${BASH_REMATCH[1]}"
  severity="${BASH_REMATCH[2]}"
  details="${BASH_REMATCH[3]}"

  validate_severity "$severity" || die "invalid severity: $severity"

  gate_status="$(state_value manual_test_gate_status "$state_file")"
  case "$gate_status" in
    prepared|in_progress|failed) ;;
    *) die "manual test gate status must be prepared, in_progress, or failed (current: $gate_status)" ;;
  esac

  local issues_file feedback_file execution_file issue_id now
  issues_file="$(manual_issues_file "$project_path")"
  feedback_file="$(manual_feedback_file "$project_path")"
  execution_file="$(manual_execution_file "$project_path")"
  issue_id="$(next_manual_issue_id "$issues_file")"
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  echo "| $issue_id | MANUAL | $title | $severity | open | $actor | software-developer | | | $now |" >> "$issues_file"
  append_manual_feedback "$feedback_file" "$actor" MANUAL "$title" "$issue_id" "$details"
  append_manual_execution "$execution_file" "$actor" MANUAL fail "$issue_id" "$details"

  reconcile_open_manual_issues "$state_file" "$issues_file"
  set_state_value "$state_file" manual_test_gate_status failed
  set_state_value "$state_file" manual_test_last_result failed
  set_state_value "$state_file" next_actor software-developer
  set_state_value "$state_file" last_actor "$actor"
  set_state_value "$state_file" command_last submit_manual_test_failed

  append_command_log "$project_path" "$actor" "$cmd" success "manual issue created: $issue_id"
  log "Manual test failure recorded as $issue_id"
}

handle_resolve_manual_issue() {
  local project_path="$1"
  local actor="$2"
  local cmd="$3"
  local state_file="$project_path/00-governance/project-state.yaml"

  require_project_state "$project_path"
  require_stage quality "$state_file"
  ensure_manual_quality_files "$project_path"

  if [[ ! "$cmd" =~ ^resolve\ manual\ issue\ (MTI-[0-9]+)\ with\ notes:\ (.+)$ ]]; then
    die "invalid resolve manual issue command format"
  fi

  local issue_id notes issues_file record source_test_id title severity status reported_by owner resolution retest updated_at
  issue_id="${BASH_REMATCH[1]}"
  notes="${BASH_REMATCH[2]}"
  [ -n "$notes" ] || die "resolution notes are required"

  issues_file="$(manual_issues_file "$project_path")"
  manual_issue_exists "$issues_file" "$issue_id" || die "manual issue not found: $issue_id"

  record="$(manual_issue_record "$issues_file" "$issue_id")"
  IFS=$'\t' read -r source_test_id title severity status reported_by owner resolution retest updated_at <<< "$record"
  [ "$status" = "open" ] || die "issue $issue_id must be open to resolve (current: $status)"

  update_manual_issue_row \
    "$issues_file" \
    "$issue_id" \
    "$source_test_id" \
    "$title" \
    "$severity" \
    "resolved_pending_retest" \
    "$reported_by" \
    "$actor" \
    "$notes" \
    "pending" \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  set_state_value "$state_file" next_actor sdet
  set_state_value "$state_file" last_actor "$actor"
  set_state_value "$state_file" command_last resolve_manual_issue

  append_command_log "$project_path" "$actor" "$cmd" success "issue moved to resolved_pending_retest"
  log "Issue $issue_id marked resolved_pending_retest"
}

handle_retest_manual_issue_passed() {
  local project_path="$1"
  local actor="$2"
  local cmd="$3"
  local state_file="$project_path/00-governance/project-state.yaml"

  require_project_state "$project_path"
  require_stage quality "$state_file"
  ensure_manual_quality_files "$project_path"

  if [[ ! "$cmd" =~ ^retest\ manual\ issue\ (MTI-[0-9]+)\ passed$ ]]; then
    die "invalid retest passed command format"
  fi

  local issue_id issues_file execution_file record source_test_id title severity status reported_by owner resolution retest updated_at
  issue_id="${BASH_REMATCH[1]}"
  issues_file="$(manual_issues_file "$project_path")"
  execution_file="$(manual_execution_file "$project_path")"

  manual_issue_exists "$issues_file" "$issue_id" || die "manual issue not found: $issue_id"

  record="$(manual_issue_record "$issues_file" "$issue_id")"
  IFS=$'\t' read -r source_test_id title severity status reported_by owner resolution retest updated_at <<< "$record"
  [ "$status" = "resolved_pending_retest" ] || die "issue $issue_id must be resolved_pending_retest (current: $status)"

  update_manual_issue_row \
    "$issues_file" \
    "$issue_id" \
    "$source_test_id" \
    "$title" \
    "$severity" \
    "closed" \
    "$reported_by" \
    "$owner" \
    "$resolution" \
    "passed by $actor" \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  append_manual_execution "$execution_file" "$actor" "$source_test_id" pass "$issue_id" "manual issue retest passed"

  reconcile_open_manual_issues "$state_file" "$issues_file"
  set_state_value "$state_file" next_actor sdet
  set_state_value "$state_file" last_actor "$actor"
  set_state_value "$state_file" command_last retest_manual_issue_passed

  append_command_log "$project_path" "$actor" "$cmd" success "issue closed after retest"
  log "Issue $issue_id closed after retest"
}

handle_retest_manual_issue_failed() {
  local project_path="$1"
  local actor="$2"
  local cmd="$3"
  local state_file="$project_path/00-governance/project-state.yaml"

  require_project_state "$project_path"
  require_stage quality "$state_file"
  ensure_manual_quality_files "$project_path"

  if [[ ! "$cmd" =~ ^retest\ manual\ issue\ (MTI-[0-9]+)\ failed:\ (.+)$ ]]; then
    die "invalid retest failed command format"
  fi

  local issue_id failure_notes issues_file feedback_file execution_file record source_test_id title severity status reported_by owner resolution retest updated_at
  issue_id="${BASH_REMATCH[1]}"
  failure_notes="${BASH_REMATCH[2]}"
  [ -n "$failure_notes" ] || die "retest failure notes are required"

  issues_file="$(manual_issues_file "$project_path")"
  feedback_file="$(manual_feedback_file "$project_path")"
  execution_file="$(manual_execution_file "$project_path")"

  manual_issue_exists "$issues_file" "$issue_id" || die "manual issue not found: $issue_id"

  record="$(manual_issue_record "$issues_file" "$issue_id")"
  IFS=$'\t' read -r source_test_id title severity status reported_by owner resolution retest updated_at <<< "$record"
  [ "$status" = "resolved_pending_retest" ] || die "issue $issue_id must be resolved_pending_retest (current: $status)"

  update_manual_issue_row \
    "$issues_file" \
    "$issue_id" \
    "$source_test_id" \
    "$title" \
    "$severity" \
    "open" \
    "$reported_by" \
    "software-developer" \
    "$resolution" \
    "failed by $actor" \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  append_manual_feedback "$feedback_file" "$actor" "$source_test_id" "retest failed" "$issue_id" "$failure_notes"
  append_manual_execution "$execution_file" "$actor" "$source_test_id" fail "$issue_id" "$failure_notes"

  reconcile_open_manual_issues "$state_file" "$issues_file"
  set_state_value "$state_file" manual_test_gate_status failed
  set_state_value "$state_file" manual_test_last_result failed
  set_state_value "$state_file" next_actor software-developer
  set_state_value "$state_file" last_actor "$actor"
  set_state_value "$state_file" command_last retest_manual_issue_failed

  append_command_log "$project_path" "$actor" "$cmd" success "issue reopened after failed retest"
  log "Issue $issue_id reopened"
}

handle_submit_manual_test_passed() {
  local project_path="$1"
  local actor="$2"
  local cmd="$3"
  local state_file="$project_path/00-governance/project-state.yaml"

  require_project_state "$project_path"
  require_stage quality "$state_file"
  ensure_manual_quality_files "$project_path"

  local open_issues gate_status
  open_issues="$(state_value open_manual_issues "$state_file")"
  gate_status="$(state_value manual_test_gate_status "$state_file")"

  [ "$open_issues" = "0" ] || die "cannot submit passed while open_manual_issues > 0"
  case "$gate_status" in
    prepared|in_progress|failed|passed) ;;
    *) die "manual test gate not started (current: $gate_status)" ;;
  esac

  set_state_value "$state_file" manual_test_gate_status passed
  set_state_value "$state_file" manual_test_last_result passed
  set_state_value "$state_file" next_actor qa-lead
  set_state_value "$state_file" last_actor "$actor"
  set_state_value "$state_file" command_last submit_manual_test_passed

  append_command_log "$project_path" "$actor" "$cmd" success "manual testing marked passed"
  log "Manual testing marked passed"
}

handle_approve_manual_test_gate() {
  local project_path="$1"
  local actor="$2"
  local cmd="$3"
  local state_file="$project_path/00-governance/project-state.yaml"

  require_project_state "$project_path"
  require_stage quality "$state_file"
  manual_gate_artifacts_present "$project_path" || die "manual gate artifacts missing"

  local gate_status open_issues
  gate_status="$(state_value manual_test_gate_status "$state_file")"
  open_issues="$(state_value open_manual_issues "$state_file")"

  [ "$gate_status" = "passed" ] || die "manual_test_gate_status must be passed (current: $gate_status)"
  [ "$open_issues" = "0" ] || die "open_manual_issues must be 0 before approval"

  append_approval_entry \
    "$project_path" \
    quality \
    "08-quality/Manual_Test_Script.md,08-quality/Manual_Test_Execution_Log.md,08-quality/Manual_Test_Feedback.md,08-quality/Manual_Test_Issues.md" \
    approved \
    "$actor" \
    "manual test gate approved"

  set_state_value "$state_file" manual_test_gate_status approved
  set_state_value "$state_file" current_item manual-test-gate-approved
  set_state_value "$state_file" next_actor project-manager
  set_state_value "$state_file" last_actor "$actor"
  set_state_value "$state_file" command_last approve_manual_test_gate

  append_command_log "$project_path" "$actor" "$cmd" success "manual test gate approved"
  log "Manual test gate approved"
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
  local stage item next_actor status manual_gate open_issues
  stage="$(state_value current_stage "$state_file")"
  item="$(state_value current_item "$state_file")"
  next_actor="$(state_value next_actor "$state_file")"
  status="$(state_value status "$state_file")"
  manual_gate="$(state_value manual_test_gate_status "$state_file")"
  open_issues="$(state_value open_manual_issues "$state_file")"

  set_state_value "$state_file" last_actor "$actor"
  set_state_value "$state_file" command_last resume_stage
  append_command_log "$project_path" "$actor" "$cmd" success "stage resumed"

  log "Current stage: $stage"
  log "Current item: $item"
  log "Status: $status"
  log "Next actor: $next_actor"
  log "Manual gate: $manual_gate"
  log "Open manual issues: $open_issues"
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
[ -f "$registry_path" ] || die "command registry not found: $registry_path"

project_path=""
if [ -n "$project_slug" ]; then
  project_path="$(project_path_from_slug "$project_slug")"
fi

command_id="$(resolve_command_id "$command_phrase" || true)"
[ -n "$command_id" ] || die "unsupported command phrase. refer to workflow/commands.md"

if [ "$command_id" != "intake_start" ]; then
  [ -n "$project_path" ] || die "--project is required for '$command_id'"
  require_project_state "$project_path"
  enforce_registry_stage "$command_id" "$project_path/00-governance/project-state.yaml"
fi

case "$command_id" in
  intake_start)
    handle_intake_start "$command_phrase" "$actor" "$project_slug"
    ;;
  review_scope)
    handle_review_scope "$project_path" "$actor" "$command_phrase"
    ;;
  lock_scope)
    handle_lock_scope "$project_path" "$actor" "$command_phrase"
    ;;
  generate_epics)
    handle_generate_epics "$project_path" "$actor" "$command_phrase"
    ;;
  start_epic)
    handle_start_epic "$project_path" "$actor" "$command_phrase"
    ;;
  start_ticket)
    handle_start_ticket "$project_path" "$actor" "$command_phrase"
    ;;
  execute_ticket)
    handle_execute_ticket "$project_path" "$actor" "$command_phrase"
    ;;
  approve_brd)
    handle_approve_brd "$project_path" "$actor" "$command_phrase"
    ;;
  reject_architecture)
    handle_reject_architecture "$project_path" "$actor" "$command_phrase"
    ;;
  prepare_manual_test)
    handle_prepare_manual_test "$project_path" "$actor" "$command_phrase"
    ;;
  start_manual_test)
    handle_start_manual_test "$project_path" "$actor" "$command_phrase"
    ;;
  submit_manual_test_failed)
    handle_submit_manual_test_failed "$project_path" "$actor" "$command_phrase"
    ;;
  resolve_manual_issue)
    handle_resolve_manual_issue "$project_path" "$actor" "$command_phrase"
    ;;
  retest_manual_issue_passed)
    handle_retest_manual_issue_passed "$project_path" "$actor" "$command_phrase"
    ;;
  retest_manual_issue_failed)
    handle_retest_manual_issue_failed "$project_path" "$actor" "$command_phrase"
    ;;
  submit_manual_test_passed)
    handle_submit_manual_test_passed "$project_path" "$actor" "$command_phrase"
    ;;
  approve_manual_test_gate)
    handle_approve_manual_test_gate "$project_path" "$actor" "$command_phrase"
    ;;
  show_blockers)
    handle_show_blockers "$project_path"
    ;;
  resume_stage)
    handle_resume_stage "$project_path" "$actor" "$command_phrase"
    ;;
  close_ticket)
    handle_close_ticket "$project_path" "$actor" "$command_phrase"
    ;;
  *)
    die "unhandled command id '$command_id'. update scripts/command-dispatch.sh."
    ;;
esac
