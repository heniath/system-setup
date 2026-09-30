# Deliberately manual components

Some workstation choices are hardware-, network-, or policy-dependent. They are
intentionally outside `setup.sh`.

## NVIDIA proprietary driver

Install a driver recommended for the exact Ubuntu release and GPU, then reboot
and verify it with `scripts/check-gpu.sh`. Driver installation can change kernel
modules, Secure Boot behavior, and display support. A generic bootstrap script
cannot safely choose or recover from the wrong driver, so neither NVIDIA drivers
nor CUDA driver packages appear in `packages/apt.txt`.

## CUDA compatibility

Choose the PyTorch build only after the NVIDIA driver works. The CUDA version
shown by `nvidia-smi` is the newest runtime API the driver supports; it is not
necessarily a locally installed CUDA toolkit. Prefer framework-provided runtimes
unless a project must compile custom CUDA code. Select PyTorch, torchvision, and
their CUDA runtime together from the framework's official compatibility matrix.

## BIOS settings

BIOS/UEFI updates, Secure Boot, virtualization, wake-on-LAN, and **Restore on AC
Power Loss** depend on the motherboard and threat model. Record choices, but
change them interactively using vendor documentation.

## SSH security

Set up and test public-key login before disabling passwords. Never automate a
change that could lock out remote access. See `configs/ssh/README.md`.

## GitHub authentication

Use SSH keys, a credential manager, or GitHub CLI authentication. Never place a
private key, personal access token, or credential helper's data in this repo.
Add a remote only after creating the repository on GitHub.

## VS Code

Install from Microsoft's current official instructions if desired. Its repository
and extension choices change over time and are not essential to bootstrap.
Export a reviewed extension list separately; do not commit extension secrets.

## Optional Tailscale

Tailscale can provide remote access behind NAT without exposing SSH publicly.
Install from official instructions, review account/device policy, and keep auth
keys out of Git.

## Optional Docker

Install only when projects require it. Docker changes daemon, group, storage,
and firewall behavior; membership in the `docker` group is effectively root-level
access. Decide on data roots and GPU container support deliberately.

## Optional smart-plug / remote-power workflow

A remotely controlled outlet plus **Restore on AC Power Loss** can recover a
truly wedged remote workstation. Confirm that the hardware tolerates abrupt
power loss, use it only as a last resort, and protect the plug account with strong
authentication. Never store its token in this repository.
