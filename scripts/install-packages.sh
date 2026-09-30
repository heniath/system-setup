#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
PACKAGE_FILE="$REPO_ROOT/packages/apt.txt"

log() { printf '[packages] %s\n' "$*"; }
die() { printf '[packages] ERROR: %s\n' "$*" >&2; exit 1; }

[[ -f "$PACKAGE_FILE" ]] || die "Package list not found: $PACKAGE_FILE"
command -v apt-get >/dev/null 2>&1 || die 'apt-get is not available.'
command -v sudo >/dev/null 2>&1 || die 'sudo is required for APT operations.'

packages=()
while IFS= read -r line || [[ -n "$line" ]]; do
  line="${line%%#*}"
  read -r -a words <<< "$line"
  for package in "${words[@]}"; do
    [[ "$package" =~ ^[a-zA-Z0-9][a-zA-Z0-9+.-]*$ ]] || die "Invalid package name: $package"
    case "$package" in
      *nvidia*|*cuda*) die "GPU package is forbidden in apt.txt: $package" ;;
    esac
    packages+=("$package")
  done
done < "$PACKAGE_FILE"

((${#packages[@]} > 0)) || die 'No packages were found.'

log "APT will refresh package metadata once, then install ${#packages[@]} reviewed packages."
log 'This uses sudo but does not install NVIDIA drivers or CUDA.'
if [[ "${1:-}" != '--yes' ]]; then
  read -r -p 'Continue with APT installation? [y/N] ' reply
  [[ "$reply" =~ ^[Yy]$ ]] || { log 'Cancelled.'; exit 0; }
fi

sudo apt-get update
sudo apt-get install --no-install-recommends -y "${packages[@]}"
log 'Package installation complete.'
