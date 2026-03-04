#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage:
  $(basename "$0") --command "<phrase>" [--project <root>] --actor <actor-id>

Single-project mode:
  - --project is optional.
  - When provided, allowed values are only "." or "root".
  - If omitted, dispatcher uses root workspace when ./00-governance/project-state.yaml exists.

Examples:
  $(basename "$0") --command "to project manager: I want to build gym erp | fe=next | be=nest | db=sqlite | cache=redis" --actor human-owner
  $(basename "$0") --command "preflight" --actor project-manager
  $(basename "$0") --command "approve stage intake" --actor sponsor
  $(basename "$0") --command "lock scope" --actor project-manager
  $(basename "$0") --command "execute current ticket" --actor software-developer
  $(basename "$0") --command "prepare manual test" --actor sdet
  $(basename "$0") --command "start next phase: advanced analytics" --actor human-owner
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
  if [ "$slug" = "." ] || [ "$slug" = "root" ]; then
    echo "."
    return
  fi
  echo ""
}

discover_default_project_path() {
  if [ -f "00-governance/project-state.yaml" ]; then
    echo "."
    return 0
  fi

  return 1
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
  local state_file="$project_path/00-governance/project-state.yaml"
  local phase_label notes_with_phase
  [ -f "$approvals" ] || {
    cat > "$approvals" <<APP
# Approvals Log

| Record Ref | Stage | Artifact(s) | Decision | Decision Maker | Notes |
| --- | --- | --- | --- | --- | --- |
APP
  }

  phase_label="none"
  if [ -f "$state_file" ]; then
    phase_label="$(state_value current_phase "$state_file")"
    [ -n "$phase_label" ] || phase_label="none"
  fi
  if [ -n "$notes" ]; then
    notes_with_phase="phase:$phase_label; $notes"
  else
    notes_with_phase="phase:$phase_label"
  fi

  echo "| $(date -u +%Y-%m-%d) | $stage | $artifacts | $decision | $decision_maker | $notes_with_phase |" >> "$approvals"
}

reset_approvals_log() {
  local project_path="$1"
  local approvals="$project_path/00-governance/approvals.md"
  cat > "$approvals" <<APP
# Approvals Log

| Record Ref | Stage | Artifact(s) | Decision | Decision Maker | Notes |
| --- | --- | --- | --- | --- | --- |
APP
}

archive_and_reset_approvals() {
  local project_path="$1"
  local completed_phase="$2"
  local approvals="$project_path/00-governance/approvals.md"
  local archive_file

  if [ -f "$approvals" ] && awk '
    {
      line=$0
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
      if (line ~ /^\|/ && line !~ /Record Ref/ && line !~ /^\|[[:space:]]*---/) {
        found=1
        exit
      }
    }
    END { exit found ? 0 : 1 }
  ' "$approvals"; then
    archive_file="$project_path/00-governance/approvals.${completed_phase}.md"
    if [ -f "$archive_file" ]; then
      archive_file="$project_path/00-governance/approvals.${completed_phase}.$(date -u +%Y%m%dT%H%M%SZ).md"
    fi
    cp "$approvals" "$archive_file"
  fi

  reset_approvals_log "$project_path"
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

has_stage_approval() {
  local project_path="$1"
  local stage="$2"
  local approvals="$project_path/00-governance/approvals.md"
  [ -f "$approvals" ] || return 1
  grep -Eiq "\|[[:space:]]*${stage}[[:space:]]*\|.*\|[[:space:]]*approved[[:space:]]*\|" "$approvals"
}

has_brd_approval() {
  local project_path="$1"
  local approvals="$project_path/00-governance/approvals.md"
  [ -f "$approvals" ] || return 1
  grep -Eiq '\|[[:space:]]*analysis[[:space:]]*\|.*BRD.*\|[[:space:]]*approved[[:space:]]*\|' "$approvals"
}

phase_register_file() {
  local project_path="$1"
  echo "$project_path/00-governance/phases.md"
}

ensure_phase_register() {
  local project_path="$1"
  local phase_file
  phase_file="$(phase_register_file "$project_path")"
  [ -f "$phase_file" ] || cat > "$phase_file" <<PHASES
# Phase Register

| Phase | Goal | Status | Requested By | Started At (UTC) | Closed At (UTC) | Notes |
| --- | --- | --- | --- | --- | --- | --- |
PHASES
}

append_phase_row() {
  local project_path="$1"
  local phase="$2"
  local goal="$3"
  local status="$4"
  local requested_by="$5"
  local started_at="$6"
  local closed_at="$7"
  local notes="$8"
  local phase_file
  phase_file="$(phase_register_file "$project_path")"
  ensure_phase_register "$project_path"
  echo "| $phase | $goal | $status | $requested_by | $started_at | $closed_at | $notes |" >> "$phase_file"
}

close_active_phase_row() {
  local project_path="$1"
  local phase="$2"
  local goal="$3"
  local notes="$4"
  local closed_at="$5"
  local phase_file tmp_file
  phase_file="$(phase_register_file "$project_path")"
  ensure_phase_register "$project_path"
  tmp_file="${phase_file}.tmp"

  if awk -F'|' -v phase="$phase" -v notes="$notes" -v closed_at="$closed_at" '
    function trim(s){ gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
    {
      if ($0 !~ /^\|/) {
        print $0
        next
      }

      p=trim($2)
      if (p=="Phase" || p=="---" || p=="") {
        print $0
        next
      }

      if (p==phase && trim($4)=="active") {
        goal=trim($3)
        requested_by=trim($5)
        started_at=trim($6)
        existing_notes=trim($8)
        merged_notes=notes
        if (existing_notes != "" && existing_notes != "-") {
          merged_notes=existing_notes "; " notes
        }
        printf "| %s | %s | completed | %s | %s | %s | %s |\n", p, goal, requested_by, started_at, closed_at, merged_notes
        updated=1
        next
      }

      print $0
    }
    END { if (!updated) exit 3 }
  ' "$phase_file" > "$tmp_file"; then
    mv "$tmp_file" "$phase_file"
    return
  fi

  rm -f "$tmp_file"
  append_phase_row "$project_path" "$phase" "$goal" "completed" "system" "unknown" "$closed_at" "$notes"
  log "Phase row for $phase was missing; appended completed fallback row."
}

append_phase_request_note() {
  local project_path="$1"
  local actor="$2"
  local cmd="$3"
  local next_phase="$4"
  local phase_goal="$5"
  local request_file="$project_path/01-intake/request.md"

  [ -f "$request_file" ] || {
    cat > "$request_file" <<REQUEST
# Intake Request

## Command Context

- Initiating command:
- Actor:

## Big-Picture Expectation

- Product name:
- Delivery model: phase-driven delivery in a single project workspace.
REQUEST
  }

  cat >> "$request_file" <<REQUEST

## Phase Request Update

- Command: $cmd
- Actor: $actor
- Requested phase: $next_phase
- Goal: $phase_goal
- Expected flow: requirements refinement -> ticketed delivery -> quality/release gates -> return to PM for next phase request.
REQUEST
}

write_intake_big_picture() {
  local project_path="$1"
  local actor="$2"
  local command="$3"
  local project_name="$4"
  local fe="$5"
  local be="$6"
  local db="$7"
  local cache="$8"
  local request_file="$project_path/01-intake/request.md"

  cat > "$request_file" <<REQUEST
# Intake Request

## Command Context

- Initiating command: $command
- Actor: $actor

## Big-Picture Expectation

- Product name: $project_name
- Delivery model: phase-driven delivery in a single project workspace.
- Phase 1 objective: MVP scope validated through full workflow gates.
- Subsequent phases: additional requirements are added by human request and routed through new phase cycle commands.

## Initial Stack Selection

- fe: $fe
- be: $be
- db: $db
- cache: $cache

## Delivery Lifecycle Expectation

1. Complete requirement and architecture workflow for current phase.
2. Execute development through approved tickets.
3. Complete quality and release gates.
4. Return to Project Manager for next-phase request from human.
REQUEST
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

next_stage_from_workflow() {
  local current_stage="$1"
  awk -v current="$current_stage" '
    /^  allowed_transitions:/ { in_transitions=1; next }
    in_transitions && $1 == current ":" {
      line=$0
      sub(/^[^[]*\[/, "", line)
      sub(/\].*$/, "", line)
      gsub(/[[:space:]]/, "", line)
      n=split(line, stages, ",")
      for (i=1; i<=n; i++) {
        if (stages[i] != "blocked" && stages[i] != "cancelled") {
          print stages[i]
          exit
        }
      }
    }
  ' workflow/workflow.yaml
}

workflow_required_artifacts_for_stage() {
  local stage="$1"
  local project_path="$2"
  awk -v target="$stage" -v workspace="$project_path" '
    $0 ~ "^    " target ":$" { in_stage=1; next }
    in_stage && $0 ~ /^      required_artifacts:/ { in_artifacts=1; next }
    in_stage && in_artifacts && $0 ~ /^        - / {
      line=$0
      sub(/^        - /, "", line)
      gsub("<workspace>", workspace, line)
      print line
      next
    }
    in_stage && in_artifacts && $0 !~ /^        - / { in_artifacts=0 }
    in_stage && $0 ~ /^    [a-z]/ { exit }
  ' workflow/workflow.yaml
}

has_method_evidence_in_file() {
  local file="$1"
  [ -f "$file" ] || return 1
  grep -Eiq 'tdd|test[- ]driven' "$file" || return 1
  grep -Eiq 'ddd|domain[- ]driven|domain model|bounded context|ubiquitous language' "$file" || return 1
  return 0
}

has_architecture_method_evidence() {
  local project_path="$1"
  has_method_evidence_in_file "$project_path/04-architecture/Architecture.md"
}

has_delivery_method_evidence() {
  local project_path="$1"
  local found_plan=false
  local found_review=false
  local file

  while IFS= read -r -d '' file; do
    if has_method_evidence_in_file "$file"; then
      found_plan=true
      break
    fi
  done < <(find "$project_path/07-delivery" -type f -name 'implementation-plan.md' -print0 2>/dev/null || true)

  while IFS= read -r -d '' file; do
    if has_method_evidence_in_file "$file"; then
      found_review=true
      break
    fi
  done < <(find "$project_path/07-delivery" -type f -name 'review-report.md' -print0 2>/dev/null || true)

  [ "$found_plan" = true ] && [ "$found_review" = true ]
}

has_quality_method_evidence() {
  local project_path="$1"
  has_method_evidence_in_file "$project_path/08-quality/Test_Strategy.md"
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

  slug="$(slugify "$product_name")"
  [ -n "$slug" ] || die "unable to derive project slug"

  if [ -n "$provided_project" ] && [ "$provided_project" != "." ] && [ "$provided_project" != "root" ]; then
    die "single-project mode is enabled. use repository root only (omit --project or pass --project .)."
  fi
  project_path="."

  if [ -f "$project_path/00-governance/project-state.yaml" ]; then
    local existing_name
    existing_name="$(state_value project_name "$project_path/00-governance/project-state.yaml")"
    if [ -n "$existing_name" ] && [ "$existing_name" != "TBD" ]; then
      die "project already initialized as '$existing_name'. this template supports one project only. continue by extending current scope/features, or run 'start next phase: <goal>' after release."
    fi
    die "project state already exists in repository root. this template supports one project only."
  fi

  ./scripts/init-project.sh --root --project-name "$slug" --fe "$fe" --be "$be" --db "$db" --cache "$cache"

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
  set_state_value "$state_file" project_mode single_project
  set_state_value "$state_file" phase_index 1
  set_state_value "$state_file" current_phase phase-1
  set_state_value "$state_file" current_phase_goal mvp
  set_state_value "$state_file" current_phase_status active

  write_intake_big_picture "$project_path" "$actor" "$cmd" "$product_name" "$fe" "$be" "$db" "$cache"
  ensure_phase_register "$project_path"
  if ! grep -Eq '^\|[[:space:]]*phase-1[[:space:]]*\|' "$project_path/00-governance/phases.md"; then
    append_phase_row "$project_path" phase-1 mvp active "$actor" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "" "initial project creation"
  fi

  append_command_log "$project_path" "$actor" "$cmd" success "intake initialized and stack locked"
  log "Project initialized at repository root with phase-1 (mvp) big picture."
}

handle_start_next_phase() {
  local project_path="$1"
  local actor="$2"
  local cmd="$3"
  local state_file="$project_path/00-governance/project-state.yaml"
  local previous_phase previous_goal previous_index next_index next_phase phase_goal

  require_project_state "$project_path"
  require_stage release "$state_file"
  has_stage_approval "$project_path" release || die "release stage must be approved before starting next phase"

  if [[ ! "$cmd" =~ ^start\ next\ phase:\ (.+)$ ]]; then
    die "invalid next phase command format"
  fi
  phase_goal="${BASH_REMATCH[1]}"
  phase_goal="$(echo "$phase_goal" | tr '\n' ' ' | sed -E 's/[[:space:]]+/ /g; s/^[[:space:]]+|[[:space:]]+$//g')"
  phase_goal="${phase_goal//|/-}"
  [ -n "$phase_goal" ] || die "next phase goal is required"

  previous_phase="$(state_value current_phase "$state_file")"
  [ -n "$previous_phase" ] || previous_phase="phase-1"
  previous_goal="$(state_value current_phase_goal "$state_file")"
  [ -n "$previous_goal" ] || previous_goal="completed phase"

  previous_index="$(state_value phase_index "$state_file")"
  if [[ ! "$previous_index" =~ ^[0-9]+$ ]]; then
    previous_index=1
  fi

  next_index=$((previous_index + 1))
  next_phase="phase-$next_index"

  close_active_phase_row \
    "$project_path" \
    "$previous_phase" \
    "$previous_goal" \
    "completed through release approval" \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  archive_and_reset_approvals "$project_path" "$previous_phase"
  append_phase_row \
    "$project_path" \
    "$next_phase" \
    "$phase_goal" \
    "active" \
    "$actor" \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    "" \
    "started from project manager next-phase command"
  append_phase_request_note "$project_path" "$actor" "$cmd" "$next_phase" "$phase_goal"

  set_state_value "$state_file" current_stage discovery
  set_state_value "$state_file" current_item "$next_phase-scope-review"
  set_state_value "$state_file" status in_progress
  set_state_value "$state_file" scope_locked false
  set_state_value "$state_file" approved_artifacts "[]"
  set_state_value "$state_file" blocked_by "[]"
  set_state_value "$state_file" active_epic none
  set_state_value "$state_file" active_ticket none
  set_state_value "$state_file" deployment_contract pending
  set_state_value "$state_file" manual_test_gate_status not_started
  set_state_value "$state_file" manual_test_last_result none
  set_state_value "$state_file" open_manual_issues 0
  set_state_value "$state_file" phase_index "$next_index"
  set_state_value "$state_file" current_phase "$next_phase"
  set_state_value "$state_file" current_phase_goal "$phase_goal"
  set_state_value "$state_file" current_phase_status active
  set_state_value "$state_file" next_actor project-manager
  set_state_value "$state_file" last_actor "$actor"
  set_state_value "$state_file" command_last start_next_phase

  append_command_log "$project_path" "$actor" "$cmd" success "next phase started: $next_phase"
  log "Started $next_phase with goal: $phase_goal"
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

  if [ "$(state_value current_stage "$state_file")" = "analysis" ]; then
    ./scripts/start-stage.sh "$project_path" planning >/dev/null
  fi
  require_stage planning "$state_file"

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
  local current_stage

  require_project_state "$project_path"
  current_stage="$(state_value current_stage "$state_file")"
  if [ "$current_stage" = "planning" ]; then
    ./scripts/start-stage.sh "$project_path" delivery >/dev/null
  fi
  require_stage delivery "$state_file"
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
  require_stage delivery "$state_file"

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

handle_advance_stage() {
  local project_path="$1"
  local actor="$2"
  local cmd="$3"
  local state_file="$project_path/00-governance/project-state.yaml"
  local current_stage target_stage

  require_project_state "$project_path"
  current_stage="$(state_value current_stage "$state_file")"
  target_stage="$(next_stage_from_workflow "$current_stage")"
  [ -n "$target_stage" ] || die "unable to determine next stage from workflow for current stage '$current_stage'"

  ./scripts/start-stage.sh "$project_path" "$target_stage" >/dev/null
  set_state_value "$state_file" last_actor "$actor"
  set_state_value "$state_file" command_last advance_stage

  append_command_log "$project_path" "$actor" "$cmd" success "stage advanced: $current_stage -> $target_stage"
  log "Advanced stage: $current_stage -> $target_stage"
}

handle_preflight() {
  local project_path="$1"
  local state_file="$project_path/00-governance/project-state.yaml"
  local current_stage next_stage
  local blockers=0

  require_project_state "$project_path"

  current_stage="$(state_value current_stage "$state_file")"
  [ -n "$current_stage" ] || die "current_stage missing in state file"
  next_stage="$(next_stage_from_workflow "$current_stage")"

  log "Current stage: $current_stage"
  log "Next stage candidate: ${next_stage:-none}"

  if has_stage_approval "$project_path" "$current_stage"; then
    log "Gate approval: present for stage '$current_stage'"
  else
    log "BLOCKER: stage approval missing for '$current_stage' (run: approve stage $current_stage)"
    blockers=$((blockers + 1))
  fi

  mapfile -t stage_artifacts < <(workflow_required_artifacts_for_stage "$current_stage" "$project_path")
  if [ "${#stage_artifacts[@]}" -eq 0 ]; then
    log "BLOCKER: unable to resolve required artifacts for stage '$current_stage' from workflow/workflow.yaml"
    blockers=$((blockers + 1))
  else
    local artifact
    for artifact in "${stage_artifacts[@]}"; do
      if [ ! -s "$artifact" ]; then
        log "BLOCKER: required artifact missing or empty for stage '$current_stage': $artifact"
        blockers=$((blockers + 1))
      fi
    done
  fi

  if [ "$current_stage" = "quality" ] && [ "$next_stage" = "release" ]; then
    local gate_status open_issues
    gate_status="$(state_value manual_test_gate_status "$state_file")"
    open_issues="$(state_value open_manual_issues "$state_file")"
    if [ "$gate_status" != "approved" ]; then
      log "BLOCKER: quality->release requires manual_test_gate_status=approved (current: $gate_status)"
      blockers=$((blockers + 1))
    fi
    if [ "$open_issues" != "0" ]; then
      log "BLOCKER: quality->release requires open_manual_issues=0 (current: $open_issues)"
      blockers=$((blockers + 1))
    fi
  fi

  if [ "$current_stage" = "delivery" ]; then
    if ! has_architecture_method_evidence "$project_path"; then
      log "BLOCKER: delivery requires stack-aware method evidence in 04-architecture/Architecture.md (TDD + domain guidance)"
      blockers=$((blockers + 1))
    fi
    if ! has_delivery_method_evidence "$project_path"; then
      log "BLOCKER: delivery requires TDD/domain evidence in implementation-plan.md and review-report.md under 07-delivery/"
      blockers=$((blockers + 1))
    fi
  fi

  if [ "$current_stage" = "quality" ]; then
    if ! has_delivery_method_evidence "$project_path"; then
      log "BLOCKER: quality requires prior delivery TDD/domain evidence in 07-delivery artifacts"
      blockers=$((blockers + 1))
    fi
    if ! has_quality_method_evidence "$project_path"; then
      log "BLOCKER: quality requires stack-aware TDD/domain strategy evidence in 08-quality/Test_Strategy.md"
      blockers=$((blockers + 1))
    fi
  fi

  if [ "$blockers" -eq 0 ]; then
    log "Preflight result: ready for stage approval/advance."
    return 0
  fi

  log "Preflight result: blocked with $blockers issue(s)."
  return 2
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

handle_approve_stage() {
  local project_path="$1"
  local actor="$2"
  local cmd="$3"
  local state_file="$project_path/00-governance/project-state.yaml"

  require_project_state "$project_path"

  if [[ ! "$cmd" =~ ^approve\ stage\ (intake|discovery|analysis|architecture|design|planning|delivery|quality|release)$ ]]; then
    die "invalid approve stage command format"
  fi

  local stage current_stage open_issues gate_status
  stage="${BASH_REMATCH[1]}"
  current_stage="$(state_value current_stage "$state_file")"
  [ "$current_stage" = "$stage" ] || die "approve stage target must match current_stage (current: $current_stage, target: $stage)"

  mapfile -t stage_artifacts < <(workflow_required_artifacts_for_stage "$stage" "$project_path")
  [ "${#stage_artifacts[@]}" -gt 0 ] || die "no required artifacts resolved for stage '$stage' in workflow/workflow.yaml"
  local artifact
  for artifact in "${stage_artifacts[@]}"; do
    [ -s "$artifact" ] || die "stage approval requires artifact present and non-empty: $artifact"
  done

  if [ "$stage" = "delivery" ]; then
    has_architecture_method_evidence "$project_path" || die "delivery stage approval requires stack-aware method evidence in 04-architecture/Architecture.md (TDD + domain guidance)"
    has_delivery_method_evidence "$project_path" || die "delivery stage approval requires TDD/domain evidence in implementation-plan.md and review-report.md under 07-delivery/"
  fi

  if [ "$stage" = "quality" ]; then
    gate_status="$(state_value manual_test_gate_status "$state_file")"
    open_issues="$(state_value open_manual_issues "$state_file")"
    [ "$gate_status" = "approved" ] || die "quality stage requires manual_test_gate_status=approved before stage approval (current: $gate_status)"
    [ "$open_issues" = "0" ] || die "quality stage approval blocked while open_manual_issues > 0"
    has_delivery_method_evidence "$project_path" || die "quality stage approval requires prior delivery TDD/domain evidence in 07-delivery artifacts"
    has_quality_method_evidence "$project_path" || die "quality stage approval requires stack-aware TDD/domain strategy evidence in 08-quality/Test_Strategy.md"
  fi

  if [ "$stage" = "release" ]; then
    [ -s "$project_path/infra/deploy/docker-compose.yml" ] || die "release stage approval requires infra/deploy/docker-compose.yml"
    [ -s "$project_path/09-release/Deployment_Readiness_Evidence.md" ] || die "release stage approval requires 09-release/Deployment_Readiness_Evidence.md"
  fi

  append_approval_entry "$project_path" "$stage" "stage-gate:$stage" approved "$actor" "stage approved via command"
  add_approved_artifact "$state_file" "stage:$stage"

  set_state_value "$state_file" current_item "$stage-approved"
  set_state_value "$state_file" last_actor "$actor"
  set_state_value "$state_file" command_last approve_stage

  append_command_log "$project_path" "$actor" "$cmd" success "stage approved: $stage"
  log "Stage approved: $stage"
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
  local stage item next_actor status manual_gate open_issues gate_approved next_required current_phase phase_goal
  stage="$(state_value current_stage "$state_file")"
  item="$(state_value current_item "$state_file")"
  next_actor="$(state_value next_actor "$state_file")"
  status="$(state_value status "$state_file")"
  current_phase="$(state_value current_phase "$state_file")"
  phase_goal="$(state_value current_phase_goal "$state_file")"
  manual_gate="$(state_value manual_test_gate_status "$state_file")"
  open_issues="$(state_value open_manual_issues "$state_file")"
  gate_approved=false
  if has_stage_approval "$project_path" "$stage"; then
    gate_approved=true
  fi

  if [ "$gate_approved" = false ]; then
    next_required="approve stage $stage"
  else
    case "$stage" in
      delivery)
        if [ "$(state_value active_ticket "$state_file")" = "none" ]; then
          next_required="start epic-<n>-ticket-<n>"
        else
          next_required="execute current ticket"
        fi
        ;;
      quality)
        if [ "$manual_gate" != "approved" ]; then
          next_required="approve manual test gate"
        else
          next_required="approve stage quality"
        fi
        ;;
      release)
        next_required="start next phase: <goal> (or keep release as final phase)"
        ;;
      *)
        next_required="continue current stage work and approval flow"
        ;;
    esac
  fi

  set_state_value "$state_file" last_actor "$actor"
  set_state_value "$state_file" command_last resume_stage
  append_command_log "$project_path" "$actor" "$cmd" success "stage resumed"

  log "Current stage: $stage"
  log "Current phase: ${current_phase:-phase-1}"
  log "Current phase goal: ${phase_goal:-mvp}"
  log "Current item: $item"
  log "Status: $status"
  log "Next actor: $next_actor"
  log "Stage gate approved: $gate_approved"
  log "Manual gate: $manual_gate"
  log "Open manual issues: $open_issues"
  log "Next required command: $next_required"
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

if [ -n "$project_slug" ] && [ "$project_slug" != "." ] && [ "$project_slug" != "root" ]; then
  die "single-project mode only accepts --project . (or --project root)."
fi

project_path=""
if [ -n "$project_slug" ]; then
  project_path="$(project_path_from_slug "$project_slug")"
else
  project_path="$(discover_default_project_path || true)"
fi

command_id="$(resolve_command_id "$command_phrase" || true)"
[ -n "$command_id" ] || die "unsupported command phrase. refer to workflow/commands.md"

if [ "$command_id" != "intake_start" ]; then
  [ -n "$project_path" ] || die "no active project state found. run intake command first in repository root."
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
  start_next_phase)
    handle_start_next_phase "$project_path" "$actor" "$command_phrase"
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
  preflight)
    handle_preflight "$project_path"
    ;;
  advance_stage)
    handle_advance_stage "$project_path" "$actor" "$command_phrase"
    ;;
  approve_brd)
    handle_approve_brd "$project_path" "$actor" "$command_phrase"
    ;;
  approve_stage)
    handle_approve_stage "$project_path" "$actor" "$command_phrase"
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
