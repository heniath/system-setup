#!/usr/bin/env bash
# Rebuild the validated Linux x86_64 environment without changing Conda base.
set -euo pipefail
REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ENV_NAME="${ML_BASE_ENV_NAME:-ml-base}"
[[ "$ENV_NAME" != base ]] || { echo 'Refusing to install into base.' >&2; exit 1; }
[[ "$(uname -sm)" == 'Linux x86_64' ]] || { echo 'Requires Linux x86_64.' >&2; exit 1; }

CONDA_BIN="${CONDA_EXE:-}"
if [[ -z "$CONDA_BIN" ]]; then
  CONDA_BIN="$(command -v conda || true)"
fi
if [[ -z "$CONDA_BIN" && -x "$HOME/miniforge3/bin/conda" ]]; then
  CONDA_BIN="$HOME/miniforge3/bin/conda"
fi
[[ -x "$CONDA_BIN" ]] || { echo 'Install Miniforge first: ./scripts/install-miniforge.sh' >&2; exit 1; }
for tool in gcc g++ nvidia-smi; do
  command -v "$tool" >/dev/null || { echo "Missing prerequisite: $tool" >&2; exit 1; }
done
nvidia-smi --query-gpu=name,driver_version --format=csv

CONDA_ROOT="$("$CONDA_BIN" info --base)"
existing="$("$CONDA_BIN" env list --json | "$CONDA_ROOT/bin/python" -c \
  'import json,sys,pathlib; name=sys.argv[1]; print(next((p for p in json.load(sys.stdin)["envs"] if pathlib.Path(p).name == name), ""))' "$ENV_NAME")"
if [[ -n "$existing" ]]; then
  echo "Environment already exists: $existing. No changes made."
  echo 'For a reviewed trial rebuild: ML_BASE_ENV_NAME=ml-base-candidate ./setup-ml-base.sh'
  exit 0
fi

"$CONDA_BIN" env create -y -n "$ENV_NAME" -f "$REPO_ROOT/environment.yml"
PREFIX="$("$CONDA_BIN" run -n "$ENV_NAME" python -c 'import sys; print(sys.prefix)')"
"$CONDA_BIN" env config vars set -n "$ENV_NAME" \
  "CUDA_HOME=$PREFIX" \
  "CPATH=$PREFIX/targets/x86_64-linux/include" \
  "LIBRARY_PATH=$PREFIX/targets/x86_64-linux/lib"
export PATH="$PREFIX/bin:$PATH"
# Conda's CUDA development packages use the targets/x86_64-linux layout.
export CUDA_HOME="$PREFIX"
export CPATH="$PREFIX/targets/x86_64-linux/include${CPATH:+:$CPATH}"
export LIBRARY_PATH="$PREFIX/targets/x86_64-linux/lib${LIBRARY_PATH:+:$LIBRARY_PATH}"
export CC=/usr/bin/gcc CXX=/usr/bin/g++
export MAX_JOBS="${MAX_JOBS:-2}"
export TORCH_CUDA_ARCH_LIST="${TORCH_CUDA_ARCH_LIST:-12.0}"
export PIP_DISABLE_PIP_VERSION_CHECK=1
PYTHON="$PREFIX/bin/python"
CONSTRAINTS="$REPO_ROOT/requirements-ml-base.txt"
pip_install() { "$PYTHON" -m pip install -c "$CONSTRAINTS" -c "$REPO_ROOT/constraints-ml-base.txt" "$@"; }

echo '[1/7] Python and build tooling supplied by environment.yml'
echo '[2/7] Matched PyTorch CUDA wheels'
pip_install torch==2.11.0+cu128 torchvision==0.26.0+cu128 torchaudio==2.11.0+cu128 \
  --index-url https://download.pytorch.org/whl/cu128
"$PYTHON" -c 'import torch; assert torch.cuda.is_available(); x=torch.ones(8,8,device="cuda"); print(torch.__version__,torch.version.cuda,(x@x).sum().item())'

echo '[3/7] Scientific and computer vision packages'
pip_install timm numpy scipy pandas scikit-learn pillow opencv-python matplotlib tqdm einops
BUILD_TMP="$(mktemp -d)"
trap 'rm -rf -- "$BUILD_TMP"' EXIT
GUI_WHEELS="$BUILD_TMP/gui-wheels"
"$PYTHON" "$REPO_ROOT/scripts/build-albumentations-gui.py" --output-dir "$GUI_WHEELS"
pip_install "$GUI_WHEELS"/albucore-*.whl "$GUI_WHEELS"/albumentations-*.whl
echo '[4/7] Hugging Face ecosystem'
pip_install transformers datasets accelerate huggingface_hub safetensors tokenizers sentencepiece
echo '[5/7] Native Mamba extensions and runtime dependencies'
pip_install ninja tilelang apache-tvm-ffi quack-kernels
"$PREFIX/bin/nvcc" --version
# Always build against this torch/Python ABI; never reuse a wheel for another torch minor.
CAUSAL_CONV1D_FORCE_BUILD=TRUE pip_install causal-conv1d --no-build-isolation --no-binary=causal-conv1d
MAMBA_FORCE_BUILD=TRUE MAMBA_KEEP_CUDA_BUILD=TRUE pip_install mamba-ssm --no-build-isolation --no-binary=mamba-ssm
echo '[6/7] Jupyter and experiment utilities'
pip_install jupyter jupyterlab ipykernel tensorboard wandb rich
echo '[7/7] Download and development tools'
pip_install kaggle gdown requests wget ipython pytest black ruff

# Restore every pinned transitive pip dependency too, excluding the GPU/native
# packages handled above and Conda-managed Python build tooling.
temp_requirements="$BUILD_TMP/remaining-requirements.txt"
"$PYTHON" - "$CONSTRAINTS" "$temp_requirements" <<'PY'
import pathlib, re, sys
exclude = {"torch", "torchvision", "torchaudio", "mamba-ssm", "causal-conv1d", "albumentations", "albucore", "pip", "setuptools", "wheel", "packaging", "cmake"}
lines = pathlib.Path(sys.argv[1]).read_text().splitlines()
pathlib.Path(sys.argv[2]).write_text("\n".join(line for line in lines if line.strip() and not line.startswith("#") and re.split(r"[= @]", line)[0].lower().replace("_", "-") not in exclude) + "\n")
PY
pip_install --no-deps -r "$temp_requirements"
"$PYTHON" -m pip check
"$PYTHON" -m ipykernel install --user --name "$ENV_NAME" --display-name "Python ($ENV_NAME)"
"$PYTHON" "$REPO_ROOT/verify-ml-base.py" --kernel-name "$ENV_NAME"
