#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ASSUME_YES=false

log() { printf '\n[setup] %s\n' "$*"; }
die() { printf '[setup] ERROR: %s\n' "$*" >&2; exit 1; }
usage() {
  cat <<'EOF'
Usage: ./setup.sh [--yes]

Orchestrates directory creation, APT packages, Miniforge, ml-base, and diagnostics.
Interactive confirmation is required before privileged or environment-changing steps.
--yes accepts those confirmations; review every script first.
EOF
}

case "${1:-}" in
  '') ;;
  --yes) ASSUME_YES=true ;;
  -h|--help) usage; exit 0 ;;
  *) usage >&2; die "Unknown option: $1" ;;
esac

run_script() {
  local script="$1"
  shift
  [[ -x "$REPO_ROOT/scripts/$script" ]] || die "Missing executable script: scripts/$script"
  "$REPO_ROOT/scripts/$script" "$@"
}

confirm_step() {
  local prompt="$1"
  if $ASSUME_YES; then return 0; fi
  local reply
  read -r -p "$prompt [y/N] " reply
  [[ "$reply" =~ ^[Yy]$ ]]
}

log 'This setup does not manage GPU drivers, CUDA drivers, SSH security, dotfiles, or BIOS settings.'
log 'It never deletes user data or overwrites dotfiles.'

run_script create-directories.sh

log 'Package installation runs apt-get update once and installs packages/apt.txt using sudo.'
if confirm_step 'Install reviewed APT packages?'; then
  run_script install-packages.sh --yes
else
  log 'Skipping APT packages.'
fi

if command -v conda >/dev/null 2>&1 || [[ -x "$HOME/miniforge3/bin/conda" ]]; then
  log 'A Conda installation is already available; Miniforge installation will be skipped safely.'
else
  log 'Miniforge installation is user-local, checksum-verified, and does not edit shell startup files.'
  if confirm_step 'Install Miniforge?'; then
    run_script install-miniforge.sh --yes
  else
    log 'Skipping Miniforge.'
  fi
fi

if command -v conda >/dev/null 2>&1 || [[ -x "$HOME/miniforge3/bin/conda" ]]; then
  if confirm_step 'Create the frozen starter ml-base environment?'; then
    run_script create-ml-env.sh --yes
  else
    log 'Skipping ml-base creation.'
  fi
else
  log 'Skipping ml-base because Conda is unavailable.'
fi

log 'Running diagnostic-only system health check.'
run_script check-system.sh
log 'Setup orchestration complete. Review manual steps in packages/manual.md.'
