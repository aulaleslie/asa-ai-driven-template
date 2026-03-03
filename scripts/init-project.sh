#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage: $(basename "$0") <project-slug> [--fe <value> --be <value> --db <value> --cache <value>]

Create a new project workspace from projects/_template and initialize governance state.
Example:
  $(basename "$0") gym-erp --fe next --be nest --db sqlite --cache redis
USAGE
}

log() {
  printf '[init-project] %s\n' "$1"
}

die() {
  log "ERROR: $1"
  exit "${2:-1}"
}

require_arg() {
  local flag="$1"
  local value="${2:-}"
  if [ -z "$value" ]; then
    die "missing value for $flag"
  fi
}

slug=""
fe=""
be=""
db=""
cache=""

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
    --fe)
      require_arg "$1" "${2:-}"
      fe="$2"
      shift 2
      ;;
    --be)
      require_arg "$1" "${2:-}"
      be="$2"
      shift 2
      ;;
    --db)
      require_arg "$1" "${2:-}"
      db="$2"
      shift 2
      ;;
    --cache)
      require_arg "$1" "${2:-}"
      cache="$2"
      shift 2
      ;;
    --*)
      die "unknown option: $1"
      ;;
    *)
      if [ -n "$slug" ]; then
        die "only one project slug is allowed"
      fi
      slug="$1"
      shift
      ;;
  esac
done

if [ -z "$slug" ]; then
  usage
  exit 1
fi

case "$slug" in
  ''|*/*|.*|*_template)
    die "invalid project slug: $slug"
    ;;
esac

src="projects/_template"
dst="projects/$slug"

[ -d "$src" ] || die "source template not found at $src"
[ ! -e "$dst" ] || die "destination already exists at $dst"

log "Creating project workspace at $dst"
cp -R "$src" "$dst"

lock_status="unlocked"
stack_locked="false"
locked_by="none"
locked_at="none"
if [ -n "$fe" ] && [ -n "$be" ] && [ -n "$db" ] && [ -n "$cache" ]; then
  lock_status="locked"
  stack_locked="true"
  locked_by="init-project"
  locked_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
fi

cat > "$dst/00-governance/project-state.yaml" <<STATE
project_name: $slug
current_stage: intake
current_item: request-intake
status: active
approved_artifacts: []
blocked_by: []
next_actor: project-manager
last_actor: none
scope_locked: false
stack_locked: $stack_locked
active_epic: none
active_ticket: none
command_last: init-project
deployment_contract: pending
STATE

cat > "$dst/00-governance/stack-lock.yaml" <<STACK
project_name: $slug
fe_stack: ${fe:-TBD}
be_stack: ${be:-TBD}
db_stack: ${db:-TBD}
cache_stack: ${cache:-TBD}
lock_status: $lock_status
locked_by: $locked_by
locked_at: $locked_at
override_required: false
STACK

if [ ! -f "$dst/00-governance/command-log.md" ]; then
  cat > "$dst/00-governance/command-log.md" <<LOG
# Command Log

| Timestamp (UTC) | Actor | Command | Result | Notes |
| --- | --- | --- | --- | --- |
LOG
fi

echo "| $(date -u +%Y-%m-%dT%H:%M:%SZ) | system | init-project | success | project initialized |" >> "$dst/00-governance/command-log.md"

# TODO: add optional owner/sponsor initialization flags.
log "Project initialized successfully."
