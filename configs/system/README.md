# Workstation operating policy

## Long-running work

Configure desktop power settings manually so the system does not automatically
suspend during training. Screen blanking is fine; suspend interrupts computation
and remote access. Verify behavior after OS upgrades.

## Restarts and remote recovery

Restart after kernel or NVIDIA driver updates, or when required to recover from a
fault. An arbitrary scheduled reboot is unnecessary and can destroy active jobs.
For a remote machine, **Restore on AC Power Loss** is an optional BIOS setting;
pairing it with a secured smart plug is a last-resort recovery mechanism, not a
normal shutdown strategy.

## State model

Installed software and the OS should be disposable. This repository captures the
reproducible blueprint. Source work, results, original data, checkpoints, papers,
and documents are irreplaceable and require independent backups. A setup repo is
not a data backup.
