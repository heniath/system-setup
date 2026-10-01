# Conda environments

`base` contains environment-management tools only. `ml-base` is the shared,
validated Python 3.11 research environment. Ordinary projects can use it directly;
incompatible or legacy repositories can use a separate environment.

Run `../setup-ml-base.sh` or `make ml-env` from the repository root. The root
`environment.yml` pins the Conda bootstrap and environment-local CUDA compiler;
`requirements-ml-base.txt` pins the Python distributions. The script installs
the matching PyTorch CUDA wheels and builds Mamba/native extensions in order.
`ml-base.yml` mirrors the root bootstrap for existing references. Creating only
this YAML does not install the complete pip/native research stack.

Run `python ../verify-ml-base.py` inside the activated environment. It checks
imports, dependency consistency, Jupyter registration, and real GPU operations.
See the root README for GUI OpenCV packaging, updates, and remote Jupyter use.

After intentional validation, export Conda builds separately from pip versions:

```bash
conda activate ml-base
conda list --explicit > environments/ml-base-lock.txt
python -m pip list --format=freeze > requirements-ml-base.txt
```

The Conda lock records exact package URLs/builds for Linux x86_64; it does not
capture pip packages. The requirements file records pip distributions, including
the two GUI OpenCV metadata variants built by the repository helper. Review
exports and never commit credentials or local secret-bearing package URLs.
