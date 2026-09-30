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
    Stable, version-pinned common ML stack

project environments
    Cloned from ml-base or created independently
    Project-specific dependencies go here
```

> Never experiment directly inside `base` or `ml-base`.

`ml-base` is a golden environment, not a day-to-day scratch space. Clone it with:

```bash
conda create -n <project-name> --clone ml-base
```

The portable `environments/ml-base.yml` expresses deliberate direct dependencies.
It omits PyTorch, torchvision, CUDA runtime, timm, transformers, and OpenCV until
versions are selected against the verified driver and official compatibility
guidance. After validation, capture exact platform-specific builds with:

```bash
conda activate ml-base
conda list --explicit > environments/ml-base-lock.txt
```

The YAML is readable and portable but allows a solver to choose transitive builds.
The explicit export is exact and reproducible on the same platform, but less
portable. Review and commit both when the stack becomes stable.

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
