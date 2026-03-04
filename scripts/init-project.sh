#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage:
  $(basename "$0") --root [--project-name <name>] [--fe <value> --be <value> --db <value> --cache <value>]
  $(basename "$0") <project-slug> [--fe <value> --be <value> --db <value> --cache <value>]

Initialize project workspace artifacts from projects/_template.
Default target is repository root when --root is used.
Examples:
  $(basename "$0") --root --project-name gym-erp --fe next --be nest --db sqlite --cache redis
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

slugify() {
  local input="$1"
  echo "$input" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g' \
    | sed -E 's/^-+|-+$//g' \
    | sed -E 's/-+/-/g'
}

root_mode=false
slug=""
project_name=""
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
    --root)
      root_mode=true
      shift
      ;;
    --project-name)
      require_arg "$1" "${2:-}"
      project_name="$2"
      shift 2
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

src="projects/_template"
[ -d "$src" ] || die "source template not found at $src"

if [ "$root_mode" = true ]; then
  [ -z "$slug" ] || die "do not pass <project-slug> when using --root"
  if [ -z "$project_name" ]; then
    project_name="$(slugify "$(basename "$PWD")")"
  fi
  [ -n "$project_name" ] || die "--project-name is required when root name cannot be derived"

  if [ -f "00-governance/project-state.yaml" ]; then
    die "root workspace is already initialized (00-governance/project-state.yaml exists)"
  fi

  required_dirs=(
    00-governance
    01-intake
    02-discovery
    03-analysis
    04-architecture
    05-design
    06-planning
    07-delivery
    08-quality
    09-release
    apps
    services
    infra
    packages
  )

  for d in "${required_dirs[@]}"; do
    [ -e "$d" ] && die "destination path already exists at ./$d"
  done

  log "Scaffolding project workspace in repository root"
  for d in "${required_dirs[@]}"; do
    cp -R "$src/$d" "./$d"
  done
  if [ ! -f "PROJECT_WORKSPACE.md" ]; then
    cp "$src/README.md" "PROJECT_WORKSPACE.md"
  fi

  dst="."
else
  if [ -z "$slug" ]; then
    usage
    exit 1
  fi

  case "$slug" in
    ''|*/*|.*|*_template)
      die "invalid project slug: $slug"
      ;;
  esac

  dst="projects/$slug"
  [ ! -e "$dst" ] || die "destination already exists at $dst"

  log "Creating project workspace at $dst"
  cp -R "$src" "$dst"
  project_name="$slug"
fi

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
project_name: $project_name
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
manual_test_gate_status: not_started
manual_test_last_result: none
open_manual_issues: 0
manual_test_script_path: 08-quality/Manual_Test_Script.md
STATE

cat > "$dst/00-governance/stack-lock.yaml" <<STACK
project_name: $project_name
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

echo "| $(date -u +%Y-%m-%dT%H:%M:%SZ) | system | init-project | success | workspace initialized at $dst |" >> "$dst/00-governance/command-log.md"

# TODO: add optional owner/sponsor initialization flags.
log "Project initialized successfully at $dst"
