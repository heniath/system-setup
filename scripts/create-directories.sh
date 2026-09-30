#!/usr/bin/env bash
set -euo pipefail

directories=(
  "$HOME/Projects/research"
  "$HOME/Projects/personal"
  "$HOME/Datasets"
  "$HOME/Experiments"
  "$HOME/Models"
  "$HOME/Tools"
  "$HOME/Archive"
)

printf 'Creating standard workstation directories (existing directories are unchanged):\n'
for directory in "${directories[@]}"; do
  mkdir -p -- "$directory"
  printf '  %s\n' "$directory"
done
