#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage: $(basename "$0") <handoff-file>

Validate that a handoff document has required fields and artifact path references.
Example: $(basename "$0") 07-delivery/epic-1/ticket-1/handoff.md
USAGE
}

log() {
  printf '[validate-handoff] %s\n' "$1"
}

die() {
  log "ERROR: $1"
  exit "${2:-1}"
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

[ "$#" -eq 1 ] || { usage; exit 1; }

handoff_file="$1"
[ -f "$handoff_file" ] || die "file not found: $handoff_file"

required_sections=(
  "Header"
  "Stack Profile Reference"
  "Deployment Impact (compose)"
  "Artifact Index"
  "Open Risks"
  "Requested Action"
)

missing=0
for section in "${required_sections[@]}"; do
  if ! grep -Fq "$section" "$handoff_file"; then
    log "MISSING: section '$section'"
    missing=1
  fi
done

if ! grep -Fq "stack-lock.yaml" "$handoff_file"; then
  log "MISSING: stack profile reference to stack-lock.yaml"
  missing=1
fi

handoff_dir="$(cd "$(dirname "$handoff_file")" && pwd)"
path_lines="$(grep -E '^- path:' "$handoff_file" || true)"
if [ -z "$path_lines" ]; then
  log "MISSING: artifact path entries in '- path: <file>' format"
  missing=1
else
  while IFS= read -r line; do
    artifact_path="$(echo "$line" | sed -E 's/^- path:[[:space:]]*//')"
    [ -n "$artifact_path" ] || continue
    if [ ! -f "$handoff_dir/$artifact_path" ]; then
      log "MISSING ARTIFACT: $artifact_path"
      missing=1
    fi
  done <<< "$path_lines"
fi

if [ "$missing" -eq 0 ]; then
  log "Handoff validation passed."
  exit 0
fi

log "Handoff validation failed."
exit 2
