#!/usr/bin/env bash
# Load shared environment from the repo-root .env. Source this from any scripts/*.sh:
#   source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_env.sh"
set -a

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$REPO_ROOT/.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: $ENV_FILE not found. cp .env.example .env and fill in values." >&2
  exit 1
fi

source "$ENV_FILE"

set +a

BS="${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}"
SCRIPT_DIR="$(cd "$(dirname "$BS")" && pwd)"
export SCRIPT_DIR REPO_ROOT

# render <template-file> -> <out-file>: substitute ${VAR} placeholders from .env.
# Policy documents / definitions may reference ${OLIST_ACCOUNT}, ${BUCKET_*}, etc.
render() {
  envsubst < "$1" > "$2"
}

# render_policy <template-file> -> prints path to a rendered temp file (for --policy-document).
render_policy() {
  local src="$1" tmp
  tmp="$(mktemp --suffix=.json)"
  envsubst < "$src" > "$tmp"
  echo "$tmp"
}