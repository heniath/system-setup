#!/usr/bin/env bash
set -uo pipefail

section() { printf '\n%s\n%s\n' "$1" '────────────────────────'; }

section 'NVIDIA GPU'
if command -v nvidia-smi >/dev/null 2>&1; then
  query='name,driver_version,temperature.gpu,memory.used,memory.total'
  if gpu_data="$(nvidia-smi --query-gpu="$query" --format=csv 2>/dev/null)"; then
    printf '%s\n' "$gpu_data"
  else
    printf 'nvidia-smi exists, but detailed GPU data could not be read.\n'
    nvidia-smi 2>/dev/null || true
  fi
  cuda_compat="$(nvidia-smi 2>/dev/null | sed -n 's/.*CUDA Version: *\([^ ]*\).*/\1/p' | head -n 1)"
  printf 'Reported CUDA compatibility: %s\n' "${cuda_compat:-unavailable}"
else
  printf 'nvidia-smi: not found (no repair attempted)\n'
fi

section 'PYTHON / PYTORCH'
if ! command -v python >/dev/null 2>&1; then
  printf 'Python: not found in the active environment\n'
  exit 0
fi

python - <<'PY'
import platform

print(f"Python: {platform.python_version()}")
try:
    import torch
except ImportError:
    print("PyTorch: not installed in the active environment")
else:
    print(f"PyTorch: {torch.__version__}")
    print(f"torch.version.cuda: {torch.version.cuda}")
    available = torch.cuda.is_available()
    print(f"torch.cuda.is_available(): {available}")
    print(f"CUDA device count: {torch.cuda.device_count()}")
    if available:
        try:
            print(f"CUDA device 0: {torch.cuda.get_device_name(0)}")
        except Exception as exc:
            print(f"CUDA device 0: unavailable ({exc})")
PY
