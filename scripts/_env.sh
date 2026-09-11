#!/usr/bin/env bash
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

render() {
  envsubst < "$1" > "$2"
}

render_policy() {
  local src="$1" tmp
  tmp="$(mktemp --suffix=.json)"
  envsubst < "$src" > "$tmp"
  echo "$tmp"
}