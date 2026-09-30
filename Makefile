.DEFAULT_GOAL := help

.PHONY: help check gpu directories packages miniforge ml-env cleanup

help: ## Show available commands (the default; no changes are made)
	@awk 'BEGIN {FS = ":.*## "} /^[a-zA-Z_-]+:.*## / {printf "  %-14s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

check: ## Print a diagnostic workstation health report
	@./scripts/check-system.sh

gpu: ## Print NVIDIA and active-Python GPU diagnostics
	@./scripts/check-gpu.sh

directories: ## Create the standard workspace directories (idempotent)
	@./scripts/create-directories.sh

packages: ## Confirm, then install the reviewed APT package list with sudo
	@./scripts/install-packages.sh

miniforge: ## Confirm, verify, and install user-local Miniforge
	@./scripts/install-miniforge.sh

ml-env: ## Confirm, then create ml-base if it does not exist
	@./scripts/create-ml-env.sh

cleanup: ## Report disk/cache usage; do not delete anything
	@./scripts/cleanup.sh
