#!/usr/bin/env bash
set -euo pipefail

size_of() {
  if [[ -e "$1" ]]; then du -sh -- "$1" 2>/dev/null | awk '{print $1}'; else printf 'not present'; fi
}

printf 'CLEANUP REPORT (no files are removed by default)\n'
printf '%s\n' '────────────────────────'
df -h / || true
printf '\n%-28s %s\n' 'APT cache' "$(size_of /var/cache/apt/archives)"
printf '%-28s %s\n' 'User cache (~/.cache)' "$(size_of "$HOME/.cache")"
printf '%-28s %s\n' 'Conda packages' "$(size_of "$HOME/miniforge3/pkgs")"
printf '%-28s %s\n' 'Downloads (report only)' "$(size_of "$HOME/Downloads")"

printf '\nProtected: datasets, checkpoints, experiments, models, Conda environments,\n'
printf 'Docker data, project files, Downloads, and user documents are never removed.\n'

if [[ "${1:-}" != '--apt-clean' ]]; then
  printf '\nPotential action: run %s --apt-clean to request APT cache cleanup.\n' "$0"
  exit 0
fi

command -v sudo >/dev/null 2>&1 || { printf 'sudo is required.\n' >&2; exit 1; }
read -r -p 'Type CLEAN APT CACHE to run sudo apt-get clean: ' confirmation
[[ "$confirmation" == 'CLEAN APT CACHE' ]] || { printf 'Cancelled; nothing removed.\n'; exit 0; }
sudo apt-get clean
printf 'APT package cache cleaned. No user data was touched.\n'
