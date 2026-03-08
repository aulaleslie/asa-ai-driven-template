#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage: $(basename "$0") [project-path]

Validate deployability contract artifacts for release.
Default project path is repository root.
Example: $(basename "$0") .
USAGE
}

log() {
  printf '[validate-deployability] %s\n' "$1"
}

die() {
  log "ERROR: $1"
  exit "${2:-1}"
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
compose_file="$project_path/project/infra/deploy/docker-compose.yml"
env_file="$project_path/project/infra/deploy/.env.example"
deploy_readme="$project_path/project/infra/deploy/README.md"
evidence_file="$project_path/09-release/Deployment_Readiness_Evidence.md"

missing=0
for f in "$compose_file" "$env_file" "$deploy_readme" "$evidence_file"; do
  if [ ! -f "$f" ]; then
    log "MISSING: $f"
    missing=1
  fi
done

if [ -f "$compose_file" ] && ! grep -Eq '^services:' "$compose_file"; then
  log "INVALID: compose file missing 'services:' root"
  missing=1
fi

if [ -f "$evidence_file" ] && ! grep -Fq 'docker compose up --build -d' "$evidence_file"; then
  log "INVALID: evidence file missing required command reference"
  missing=1
fi

if [ "$missing" -eq 0 ]; then
  log "Deployability contract validation passed."
  exit 0
fi

log "Deployability contract validation failed."
exit 2
