#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
line() { printf '%-13s %s\n' "$1" "$2"; }

printf 'SYSTEM HEALTH\n────────────────────────\n'

if [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  os="${PRETTY_NAME:-unknown}"
else
  os='unknown'
fi
line 'OS' "$os"
line 'Kernel' "$(uname -r 2>/dev/null || printf unknown)"
line 'Hostname' "$(hostname 2>/dev/null || printf unknown)"
line 'Uptime' "$(uptime -p 2>/dev/null || printf unknown)"
cpu="$(awk -F: '/model name/ {sub(/^[[:space:]]+/, "", $2); print $2; exit}' /proc/cpuinfo 2>/dev/null)"
line 'CPU' "${cpu:-unknown}"
if command -v free >/dev/null 2>&1; then
  line 'RAM' "$(free -h | awk '/^Mem:/ {print $3 " used / " $2 " total"}')"
else
  line 'RAM' 'unknown'
fi
line 'Root disk' "$(df -hP / 2>/dev/null | awk 'NR==2 {print $3 " used / " $2 " (" $5 ")"}')"
line 'Git' "$(git --version 2>/dev/null || printf 'not found')"

if command -v conda >/dev/null 2>&1; then
  line 'Conda' "$(conda --version 2>/dev/null)"
elif [[ -x "$HOME/miniforge3/bin/conda" ]]; then
  line 'Conda' "$($HOME/miniforge3/bin/conda --version 2>/dev/null) (not on PATH)"
else
  line 'Conda' 'not found'
fi
line 'Conda env' "${CONDA_DEFAULT_ENV:-none active}"

if command -v systemctl >/dev/null 2>&1; then
  ssh_state="$(systemctl is-active ssh 2>/dev/null || true)"
  line 'SSH' "${ssh_state:-unavailable}"
else
  line 'SSH' 'systemctl unavailable'
fi

if command -v nvidia-smi >/dev/null 2>&1; then
  if gpu_data="$(nvidia-smi --query-gpu=name,driver_version --format=csv,noheader,nounits 2>/dev/null)"; then
    gpu="$(printf '%s\n' "$gpu_data" | cut -d, -f1 | paste -sd ';' -)"
    driver="$(printf '%s\n' "$gpu_data" | cut -d, -f2- | sed 's/^[[:space:]]*//' | sort -u | paste -sd ',' -)"
    line 'GPU' "${gpu:-query returned no devices}"
    line 'NVIDIA' "driver ${driver:-unknown}"
  else
    line 'GPU' 'query failed'
    line 'NVIDIA' 'nvidia-smi cannot communicate with the driver'
  fi
else
  line 'GPU' 'nvidia-smi not found'
  line 'NVIDIA' 'unavailable'
fi

if command -v curl >/dev/null 2>&1 && curl --silent --head --fail --max-time 3 https://github.com >/dev/null 2>&1; then
  line 'Network' 'outbound HTTPS available'
else
  line 'Network' 'offline, blocked, or check timed out'
fi

printf '\nWORKSPACE USAGE\n────────────────────────\n'
for directory in Projects Datasets Experiments Models Tools Archive; do
  if [[ -d "$HOME/$directory" ]]; then
    line "$directory" "$(du -sh -- "$HOME/$directory" 2>/dev/null | awk '{print $1}')"
  else
    line "$directory" 'not created'
  fi
done

printf '\nGPU DETAILS\n────────────────────────\n'
"$SCRIPT_DIR/check-gpu.sh"
