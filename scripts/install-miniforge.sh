#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="${MINIFORGE_HOME:-$HOME/miniforge3}"
RELEASE_BASE='https://github.com/conda-forge/miniforge/releases/latest/download'
INSTALLER_NAME='Miniforge3-Linux-x86_64.sh'
INSTALLER_URL="$RELEASE_BASE/$INSTALLER_NAME"
CHECKSUM_URL="$INSTALLER_URL.sha256"

log() { printf '[miniforge] %s\n' "$*"; }
die() { printf '[miniforge] ERROR: %s\n' "$*" >&2; exit 1; }

if command -v conda >/dev/null 2>&1; then
  log "Conda already exists at $(command -v conda); leaving it unchanged."
  exit 0
fi

if [[ -x "$INSTALL_DIR/bin/conda" ]]; then
  log "An installation already exists at $INSTALL_DIR; leaving it unchanged."
  log "Activate it with: source \"$INSTALL_DIR/etc/profile.d/conda.sh\""
  exit 0
fi

[[ ! -e "$INSTALL_DIR" ]] || die "Path exists but is not a recognized Conda installation: $INSTALL_DIR"
[[ "$(uname -s)" == 'Linux' ]] || die 'Only Linux is supported.'
[[ "$(uname -m)" == 'x86_64' ]] || die 'This script supports Linux x86_64 only.'
command -v curl >/dev/null 2>&1 || die 'curl is required.'
command -v sha256sum >/dev/null 2>&1 || die 'sha256sum is required.'

log "This will download Miniforge from its official conda-forge GitHub release."
log "It will verify the published SHA-256 checksum and install to $INSTALL_DIR."
log 'It will not use sudo, modify shell startup files, or run conda init.'
if [[ "${1:-}" != '--yes' ]]; then
  read -r -p 'Continue with Miniforge installation? [y/N] ' reply
  [[ "$reply" =~ ^[Yy]$ ]] || { log 'Cancelled.'; exit 0; }
fi

temp_dir="$(mktemp -d)"
cleanup() { rm -rf -- "$temp_dir"; }
trap cleanup EXIT

curl --fail --location --proto '=https' --tlsv1.2 \
  --output "$temp_dir/$INSTALLER_NAME" "$INSTALLER_URL"
curl --fail --location --proto '=https' --tlsv1.2 \
  --output "$temp_dir/$INSTALLER_NAME.sha256" "$CHECKSUM_URL"

(
  cd "$temp_dir"
  sha256sum --check "$INSTALLER_NAME.sha256"
)

bash "$temp_dir/$INSTALLER_NAME" -b -p "$INSTALL_DIR"
log "Installed Miniforge at $INSTALL_DIR."
log "Activate it with: source \"$INSTALL_DIR/etc/profile.d/conda.sh\""
