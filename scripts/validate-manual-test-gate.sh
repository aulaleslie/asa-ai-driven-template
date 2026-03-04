#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage: $(basename "$0") [project-path]

Validate manual-test gate artifacts and state consistency.
Default project path is repository root.
Example: $(basename "$0") .
USAGE
}

log() {
  printf '[validate-manual-test-gate] %s\n' "$1"
}

die() {
  log "ERROR: $1"
  exit "${2:-1}"
}

state_value() {
  local key="$1"
  local state_file="$2"
  grep -E "^${key}:" "$state_file" | sed -E "s/^${key}:\s*//" | head -n1
}

count_open_issues() {
  local issues_file="$1"
  awk -F'|' '
    /^\|/ {
      issue=$2; status=$6
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", issue)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", status)
      if (issue == "Issue ID" || issue == "---" || issue == "") next
      if (status != "closed") c++
    }
    END { print c+0 }
  ' "$issues_file"
}

validate_issue_statuses() {
  local issues_file="$1"
  awk -F'|' '
    function trim(s){ gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
    BEGIN { ok=1 }
    /^\|/ {
      issue=trim($2)
      status=trim($6)
      if (issue=="Issue ID" || issue=="---" || issue=="") next
      if (status!="open" && status!="resolved_pending_retest" && status!="closed") {
        ok=0
      }
    }
    END { if (!ok) exit 11 }
  ' "$issues_file"
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

if [ "$#" -gt 1 ]; then
  usage
  exit 1
fi

project_path="${1:-.}"
state_file="$project_path/00-governance/project-state.yaml"
script_file="$project_path/08-quality/Manual_Test_Script.md"
execution_file="$project_path/08-quality/Manual_Test_Execution_Log.md"
feedback_file="$project_path/08-quality/Manual_Test_Feedback.md"
issues_file="$project_path/08-quality/Manual_Test_Issues.md"

[ -f "$state_file" ] || die "missing state file: $state_file"
missing=0
for f in "$script_file" "$execution_file" "$feedback_file" "$issues_file"; do
  if [ ! -f "$f" ]; then
    log "MISSING: $f"
    missing=1
  fi
done

if [ "$missing" -ne 0 ]; then
  log "Manual-test gate validation failed."
  exit 2
fi

open_from_file="$(count_open_issues "$issues_file")"
open_from_state="$(state_value open_manual_issues "$state_file")"
status="$(state_value manual_test_gate_status "$state_file")"

if [ -z "$open_from_state" ]; then
  log "MISSING state key: open_manual_issues"
  exit 2
fi

if [ "$open_from_file" != "$open_from_state" ]; then
  log "MISMATCH: open_manual_issues state=$open_from_state file=$open_from_file"
  exit 2
fi

if ! validate_issue_statuses "$issues_file"; then
  log "INVALID: Manual_Test_Issues.md contains unsupported status values"
  exit 2
fi

if [ "$status" = "approved" ] && [ "$open_from_state" != "0" ]; then
  log "INVALID: gate cannot be approved while open_manual_issues > 0"
  exit 2
fi

log "Manual-test gate validation passed."
