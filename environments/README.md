# Conda environments

The environment hierarchy is intentionally small:

```text
base                 Conda/environment management only
ml-base              Stable, version-pinned common ML stack (golden environment)
project environments Cloned from ml-base or built independently
```

> Never experiment directly inside `base` or `ml-base`.

Create the golden environment with `scripts/create-ml-env.sh`, then clone it for
a project:

```bash
conda create -n my-project --clone ml-base
conda activate my-project
```

`ml-base.yml` is a portable, human-maintained specification. It describes direct
dependencies and can be solved across compatible systems, so transitive versions
may change. After validating the environment on the target workstation, produce
an exact, platform-specific artifact:

```bash
conda activate ml-base
conda list --explicit > environments/ml-base-lock.txt
```

That explicit file captures exact package builds and URLs for reliable recreation
on the same platform. Review it before committing it. It is less portable than
the YAML and should be regenerated only after intentional environment changes.

PyTorch and its CUDA runtime are deliberately absent from the starter YAML.
After the driver is verified, use the official PyTorch selector/compatibility
matrix and record the chosen versions here. Add `torch`, `torchvision`, `timm`,
`transformers`, and OpenCV only when their compatibility has been decided.
