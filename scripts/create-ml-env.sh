#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
printf '%s\n' '[ml-env] Creates the validated general-purpose ml-base stack.'
printf '%s\n' '[ml-env] Existing environments are left unchanged; Conda base stays minimal.'
if [[ "${1:-}" != '--yes' ]]; then
  read -r -p 'Create ml-base, including CUDA wheels and native extension builds? [y/N] ' reply
  [[ "$reply" =~ ^[Yy]$ ]] || { printf '%s\n' '[ml-env] Cancelled.'; exit 0; }
fi
exec bash "$REPO_ROOT/setup-ml-base.sh"
