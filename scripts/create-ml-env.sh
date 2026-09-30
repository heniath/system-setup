#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$REPO_ROOT/environments/ml-base.yml"

log() { printf '[ml-env] %s\n' "$*"; }
die() { printf '[ml-env] ERROR: %s\n' "$*" >&2; exit 1; }

find_conda() {
  if command -v conda >/dev/null 2>&1; then
    command -v conda
  elif [[ -x "$HOME/miniforge3/bin/conda" ]]; then
    printf '%s\n' "$HOME/miniforge3/bin/conda"
  elif [[ -x "$HOME/mambaforge/bin/conda" ]]; then
    printf '%s\n' "$HOME/mambaforge/bin/conda"
  else
    return 1
  fi
}

CONDA_BIN="$(find_conda)" || die 'Conda was not found. Install Miniforge first.'
[[ -f "$ENV_FILE" ]] || die "Environment file not found: $ENV_FILE"

if "$CONDA_BIN" env list --json | grep -qE '[/\\]envs[/\\]ml-base"'; then
  log 'ml-base already exists; it will not be changed automatically.'
  log "Review differences first: $CONDA_BIN env update --name ml-base --file \"$ENV_FILE\" --dry-run"
  log 'Clone for a project with: conda create -n <project-name> --clone ml-base'
  exit 0
fi

log "Conda: $CONDA_BIN"
log "Environment definition: $ENV_FILE"
log 'This creates ml-base and does not modify the base environment.'
if [[ "${1:-}" != '--yes' ]]; then
  read -r -p 'Create the ml-base environment? [y/N] ' reply
  [[ "$reply" =~ ^[Yy]$ ]] || { log 'Cancelled.'; exit 0; }
fi

"$CONDA_BIN" env create --file "$ENV_FILE"
log 'Created ml-base. Never experiment directly in base or ml-base.'
log 'Clone it with: conda create -n <project-name> --clone ml-base'
