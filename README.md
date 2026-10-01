# system-setup

A conservative, reproducible blueprint for rebuilding an Ubuntu machine used for
machine-learning research, development, long-running training, and remote access.
It records intent and repeatable setup steps without pretending that risky hardware
or security decisions can be automated safely.

The goal is not to preserve the operating system forever. The goal is to make the
OS disposable because the workstation can be reconstructed reliably.

## Design philosophy

```text
Disposable
    Ubuntu
    installed programs
    Conda environments

Reproducible
    system-setup repository

Irreplaceable
    source code not yet pushed
    research results
    original datasets
    important checkpoints
    papers/documents
```

Scripts are readable, narrowly scoped, and safe to rerun. They stop on errors,
avoid overwriting configuration, and require confirmation before privileged or
environment-changing operations. GPU drivers, CUDA choices, SSH hardening,
dotfile replacement, and BIOS changes remain manual.

## Repository layout

```text
.
├── README.md                 This guide and recovery plan
├── setup.sh                  Conservative setup orchestrator
├── Makefile                  Explicit convenience targets
├── packages/                 Reviewed APT list and manual components
├── environments/             Portable golden-environment definition
├── dotfiles/                 Sanitized examples, never live dotfiles
├── configs/                  SSH and operating-policy documentation
└── scripts/                  Small install and diagnostic tools
```

## Fresh installation procedure

1. Install a supported Ubuntu release and apply normal OS updates.
2. Install the NVIDIA proprietary driver manually using guidance appropriate for
   the exact Ubuntu release, GPU, and Secure Boot state.
3. Reboot and verify the driver with `nvidia-smi`; do not install a CUDA toolkit
   merely because a framework may need a CUDA runtime.
4. Install Git if the base installation does not include it, then clone this repo.
5. Read this README, `packages/manual.md`, and every script that will run.
6. Run `./scripts/check-gpu.sh`, then `./setup.sh` and approve each desired stage.
7. Merge selected dotfile examples manually; never overwrite live dotfiles blindly.
8. Review SSH and system policies in `configs/` and apply them manually.
9. Run `./scripts/check-system.sh` and resolve any reported issue deliberately.

Conceptually:

```text
Fresh Ubuntu → manual NVIDIA driver → GPU verification → clone repository
→ setup.sh → packages → Miniforge → ml-base → manual dotfiles
→ workspace directories → health check → ready
```

## Running setup

First inspect the plan:

```bash
make help
./setup.sh --help
```

Then run interactively:

```bash
./setup.sh
```

The script creates directories, offers to install the reviewed APT list, offers a
checksum-verified user-local Miniforge installation, offers to create `ml-base`,
and prints a health report. APT is the only stage that uses `sudo`. `--yes` exists
for a reviewed unattended run, but it should not be used on an unfamiliar revision.
No step changes NVIDIA/CUDA drivers, SSH policy, dotfiles, or BIOS settings.

Individual tasks are available through `make directories`, `make packages`,
`make miniforge`, and `make ml-env`. Plain `make` only prints help.

## Conda environment policy

```text
base
    Conda/environment management only

ml-base
    Stable, version-pinned general-purpose research stack

project environments
    Used when a repository has genuinely incompatible dependencies
```

Keep `base` for environment management. Use `ml-base` for ordinary research;
review and validate dependency changes before altering the shared environment.

When isolation is needed, clone the working environment with:

```bash
conda create -n <project-name> --clone ml-base
```

`ml-base` is now the general-purpose research environment described below.
Use it directly for compatible ML, CV, Hugging Face, and Mamba projects. Keep
Conda `base` minimal. Create a separate project environment when a repository
requires incompatible dependencies; cloning is optional for ordinary projects.
The root `environment.yml` pins the Conda bootstrap and CUDA development tools;
`requirements-ml-base.txt` records exact Python distributions after validation.
`environments/ml-base.yml` mirrors the root bootstrap for compatibility.
The ordered installer is `setup-ml-base.sh`, also used by `make ml-env`.
After intentional validation, capture exact platform-specific Conda builds with:

```bash
conda activate ml-base
conda list --explicit > environments/ml-base-lock.txt
```

The explicit Conda export covers Conda packages only; pip packages require the
separate requirements file. Review both before committing.

## General-purpose ML environment

This workstation uses Python 3.11 and an explicitly matched PyTorch 2.11.0,
torchvision 0.26.0, torchaudio 2.11.0 stack with CUDA 12.8 wheels and Triton 3.6.0.
The RTX 5060 Ti is Blackwell (`sm_120`). The CUDA 13.2 label in `nvidia-smi`
describes driver capability; PyTorch uses its own CUDA 12.8 runtime. These
choices follow the [official PyTorch version table](https://pytorch.org/get-started/previous-versions/).
PyTorch 2.11 is the latest coordinated published trio including the requested
torchaudio; Mamba compatibility is not the reason for selecting it.

The environment includes the scientific/CV stack, Hugging Face libraries,
Mamba, Jupyter, experiment tracking, Kaggle/download clients, and development
tools. Exact installed versions are in `requirements-ml-base.txt`.

Create it on Ubuntu x86_64 with a working NVIDIA driver, Git, GCC/G++, and Conda:

```bash
cd ~/system-setup
./scripts/install-miniforge.sh  # only if Conda is missing; verifies SHA-256
./setup-ml-base.sh
```

The installer creates only the named environment and refuses to modify an
existing environment automatically. It leaves `base`, drivers, SSH, system
CUDA, and shell startup files alone. The `environment.yml` file alone installs
the Conda bootstrap; the script completes the ordered pip and native-build
stages. Allow time and disk space for CUDA wheels and native compilation.

Activate and verify:

```bash
source ~/miniforge3/etc/profile.d/conda.sh  # if conda is not initialized
conda activate ml-base
python ~/system-setup/verify-ml-base.py
python -c 'import torch; print(torch.__version__, torch.version.cuda, torch.cuda.is_available(), torch.cuda.get_device_name(0))'
```

The automated check tests imports, real CUDA matrix multiplication and backward,
torchvision CUDA NMS, timm and Transformer GPU forwards, native causal-conv1d
against its reference, Mamba/Mamba2 GPU forward/backward (including Triton),
GUI OpenCV build support, the Jupyter kernel, and `pip check`. No model downloads
or cloud logins are needed. A JSON report can be written with
`python verify-ml-base.py --report ml-base-verification.json`.

### Mamba and native CUDA extensions

`mamba-ssm` 2.3.2.post1 and `causal-conv1d` 1.7.0 are built locally against this
exact Python/PyTorch ABI. Their published wheels do not cover PyTorch 2.11.
The [released Mamba sources](https://github.com/state-spaces/mamba/tree/v2.3.2.post1)
and [causal-conv1d sources](https://github.com/Dao-AILab/causal-conv1d/tree/v1.7.0)
include Blackwell targets when compiled with CUDA 12.8 or newer.

Only the environment-local NVIDIA CUDA compiler and development headers are
added via Conda, because these native extensions require them. A small CUDA
development runtime is pulled in with those headers; CUDA math libraries and
cuDNN come from the PyTorch wheels. No full system CUDA toolkit is installed.
The pip `cuda-toolkit` distribution selected by torch is a small runtime
dependency selector, not a system toolkit installation.

The installer records CUDA include/library paths as environment-specific Conda
variables, so activation supplies them for later native builds, and
limits compilation to two concurrent build jobs. It builds from the pinned
released sources, with build isolation disabled so the installed GPU torch is
used. Changing PyTorch requires rebuilding and retesting both native extensions.
The full Mamba package also needs its pinned TileLang/TVM/Quack dependencies;
these are recorded with the rest of the environment.

### OpenCV GUI support

Use the GUI-enabled `opencv-python` package so `cv2.imshow` is available when a
graphical display is available. An ordinary SSH session does not itself provide
a display; remote GUI use needs suitable display forwarding or a desktop session.

Upstream Albumentations 2.0.8 and Albucore 0.0.24 require
`opencv-python-headless` in their pip metadata. Installing GUI and headless
OpenCV together would overwrite the same `cv2` files. The script
`scripts/build-albumentations-gui.py` downloads checksum-pinned official wheels
and changes only the OpenCV dependency to `opencv-python`, adding the explicit
local version suffix `+opencv.gui`. It preserves and compares the original
Python code byte-for-byte and regenerates wheel records. These two local wheels
are rebuilt automatically; keep this helper with the requirements file.

### Jupyter and remote use

The installed kernel is **Python (ml-base)**, with internal name `ml-base`:

```bash
conda activate ml-base
python -m ipykernel install --user --name ml-base --display-name 'Python (ml-base)'
jupyter lab --no-browser --ip=127.0.0.1 --port=8888
```

For access from your laptop, create an SSH tunnel, then open the localhost URL
with the token printed by Jupyter:

```bash
ssh -L 8888:127.0.0.1:8888 heniath@100.69.174.24
```

Authenticate Kaggle, Hugging Face, and W&B separately when using their online
services. Keep tokens, credential files, notebook access tokens, and datasets
out of this repository. Import checks do not verify account authorization.

### Safe updates and reproducibility

Avoid indiscriminate `pip install -U` or installing an unfamiliar repository's
requirements over the shared stack. Inspect requested dependencies first. To
test a change independently, create a candidate from the recorded files:

```bash
ML_BASE_ENV_NAME=ml-base-candidate ./setup-ml-base.sh
conda activate ml-base-candidate
python verify-ml-base.py --kernel-name ml-base-candidate
```

Review changed constraints, test representative projects and GPU kernels, then
adopt and export the deliberate change. Never solve a Mamba or legacy repository
conflict by silently replacing the shared torch/CUDA/Triton stack. Unusual or
legacy repositories may still require their own isolated environment; no single
environment can guarantee compatibility with all future projects.

After a successful intentional update:

```bash
conda activate ml-base
python verify-ml-base.py --report ml-base-verification.json
python -m pip list --format=freeze > requirements-ml-base.txt
conda list --explicit > environments/ml-base-lock.txt
conda env export --no-builds > /tmp/ml-base-full-export.yml
git diff --check
git diff
```

Keep the curated `environment.yml` bootstrap in sync with the Conda export.
`pip list --format=freeze` records portable version pins instead of local wheel
paths; GUI-adjusted wheels require the helper above. PyTorch CUDA wheel pins
require the official CUDA 12.8 index used by `setup-ml-base.sh`. Native wheel
artifacts are cached under `~/.cache/ml-base-wheels/`; source rebuilding is the
default so a fresh installation never assumes another machine's torch ABI.
The explicit Conda lock is Linux/platform-specific. Review exports for secrets
before committing. The snapshot records the validated combination, not a promise
that every upstream release will remain available forever.

## Workspace directory policy

```text
~/Projects/
├── research/
└── personal/

~/Datasets/
~/Experiments/
~/Models/
~/Tools/
~/Archive/
```

Code belongs under `Projects`; reusable input data under `Datasets`; run outputs
and logs under `Experiments`; retained weights under `Models`; standalone tools
under `Tools`; and inactive material under `Archive`. `~/Downloads` is a temporary
inbox: review, rename, and move useful files instead of treating it as storage.

These large/content directories are not part of this Git repository and need
their own retention and backup policies.

## Health checks and cleanup

```bash
make check       # whole-system diagnostic report
make gpu         # NVIDIA and active Python/PyTorch details
make cleanup     # disk/cache report only
```

Diagnostics never repair or reconfigure the system. Network checking makes a
short outbound HTTPS request. Cleanup reports candidates; only
`scripts/cleanup.sh --apt-clean` offers one narrow deletion and requires the exact
interactive confirmation phrase. It never removes user files, datasets, models,
experiments, Conda environments, Docker data, or Downloads.

## Updating the blueprint

After an intentional workstation change:

1. Decide whether it is globally reproducible or project-specific.
2. Update the smallest relevant package list, environment definition, example,
   or policy document. Never copy a live secret-bearing configuration wholesale.
3. Review the diff: `git diff --check && git diff`.
4. Validate shell syntax: `bash -n setup.sh scripts/*.sh` and run ShellCheck when
   available: `shellcheck setup.sh scripts/*.sh`.
5. Run relevant diagnostic or dry-run behavior, then commit the reason for change.

## Never commit

Never commit private SSH keys, passwords, API keys, access/refresh tokens, `.env`
files, cloud credentials, Git credential stores, browser profiles, private host
inventories, VPN auth keys, smart-plug credentials, shell history, personal data,
or unreviewed copies of live dotfiles. `.gitignore` is defensive, but it is not a
security boundary: inspect every staged diff with `git diff --cached`.

If a secret is committed, removing the file in a later commit is insufficient.
Revoke/rotate the credential immediately and rewrite published history if needed.

## Backup strategy

Use multiple independent layers:

- Push this repository and source repositories to authenticated remote Git hosts.
- Back up original datasets, results, checkpoints, papers, and documents to at
  least one separate device and one off-site location where permitted.
- Use versioning or immutable snapshots so deletion and corruption are recoverable.
- Encrypt sensitive backups, protect recovery keys separately, and test restores.
- Record provenance and checksums for datasets that can legally be reacquired.

Git, cloud sync, RAID, and this repository each solve different problems; none is
a complete backup alone.

## Disaster recovery

1. Secure accounts and replace failed or compromised hardware if necessary.
2. Restore Ubuntu from trusted installation media and apply security updates.
3. Install and verify the NVIDIA driver manually.
4. Clone this repository from its remote and review the current revision.
5. Run the setup flow, restore only reviewed dotfiles, and perform health checks.
6. Restore irreplaceable data from a tested backup, preserving permissions and
   checksums. Re-clone pushed source rather than restoring stale working copies.
7. Recreate project environments from recorded files or clone the golden base.
8. Re-establish SSH/VPN access carefully and rotate credentials after compromise.
9. Validate representative training, storage, backup, and remote-access workflows.

See `packages/manual.md` for choices that must remain deliberate and
`configs/system/README.md` for the long-running workstation policy.
