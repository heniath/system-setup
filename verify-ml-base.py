#!/usr/bin/env python
"""Offline import and real GPU checks; writes a report only when requested."""

import argparse
import json
import os
import platform
import subprocess
import sys
import traceback
from importlib import metadata
from pathlib import Path

os.environ.setdefault("ALBUMENTATIONS_NO_TELEMETRY", "1")
os.environ.setdefault("NO_ALBUMENTATIONS_UPDATE", "1")
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--report", type=Path)
parser.add_argument("--kernel-name", default="ml-base")
args = parser.parse_args()
report = {"python": platform.python_version(), "checks": {}, "versions": {}}


def check(name, fn):
    try:
        result = fn()
        report["checks"][name] = {"passed": True, "detail": result}
        print(f"PASS {name}: {result}", flush=True)
    except (Exception, SystemExit) as exc:  # noqa: BLE001
        report["checks"][name] = {"passed": False, "detail": str(exc)}
        print(f"FAIL {name}: {exc}", flush=True)
        traceback.print_exc()


modules = {
    "torch": "torch",
    "torchvision": "torchvision",
    "torchaudio": "torchaudio",
    "timm": "timm",
    "numpy": "numpy",
    "scipy": "scipy",
    "pandas": "pandas",
    "sklearn": "scikit-learn",
    "PIL": "pillow",
    "cv2": "opencv-python",
    "albumentations": "albumentations",
    "matplotlib": "matplotlib",
    "tqdm": "tqdm",
    "einops": "einops",
    "transformers": "transformers",
    "datasets": "datasets",
    "accelerate": "accelerate",
    "huggingface_hub": "huggingface-hub",
    "safetensors": "safetensors",
    "tokenizers": "tokenizers",
    "sentencepiece": "sentencepiece",
    "triton": "triton",
    "mamba_ssm": "mamba-ssm",
    "causal_conv1d": "causal-conv1d",
    "ninja": "ninja",
    "jupyter": "jupyter",
    "jupyterlab": "jupyterlab",
    "ipykernel": "ipykernel",
    "tensorboard": "tensorboard",
    "wandb": "wandb",
    "rich": "rich",
    "kaggle": "kaggle",
    "gdown": "gdown",
    "requests": "requests",
    "wget": "wget",
    "IPython": "ipython",
    "pytest": "pytest",
    "black": "black",
}


def import_package(module, distribution):
    # A subprocess contains import-time exits and avoids hanging on credentials.
    proc = subprocess.run(
        [
            sys.executable,
            "-c",
            f"import importlib; importlib.import_module({module!r})",
        ],
        capture_output=True,
        text=True,
        timeout=90,
        check=False,
    )
    version = metadata.version(distribution)
    report["versions"][distribution] = version
    if proc.returncode:
        raise RuntimeError((proc.stderr or proc.stdout)[-3000:])
    return version


for module, distribution in modules.items():
    check(f"import {module}", lambda m=module, d=distribution: import_package(m, d))
check(
    "ruff",
    lambda: subprocess.check_output(
        [sys.executable, "-m", "ruff", "--version"], text=True
    ).strip(),
)


def cuda_tensor():
    import torch

    print("torch.__version__:", torch.__version__)
    print("torch.version.cuda:", torch.version.cuda)
    print("torch.cuda.is_available():", torch.cuda.is_available())
    assert torch.cuda.is_available(), "CUDA is unavailable"
    print("torch.cuda.get_device_name(0):", torch.cuda.get_device_name(0))
    report.update(
        pytorch=torch.__version__,
        cuda_runtime=torch.version.cuda,
        gpu=torch.cuda.get_device_name(0),
        capability=list(torch.cuda.get_device_capability(0)),
    )
    a = torch.arange(256, dtype=torch.float32).reshape(16, 16)
    out = a.cuda() @ a.T.cuda()
    torch.cuda.synchronize()
    assert out.is_cuda
    torch.testing.assert_close(out.cpu(), a @ a.T)
    x = torch.randn(32, 32, device="cuda", requires_grad=True)
    (x @ x.T).square().mean().backward()
    torch.cuda.synchronize()
    assert torch.isfinite(x.grad).all()
    return "CUDA matrix multiplication and backward matched expectations"


check("CUDA tensor", cuda_tensor)


def vision():
    import albumentations as A
    import cv2
    import numpy as np
    import timm
    import torch
    import torchvision

    boxes = torch.tensor([[0.0, 0.0, 2.0, 2.0], [0.0, 0.0, 1.0, 1.0]], device="cuda")
    scores = torch.tensor([0.9, 0.8], device="cuda")
    assert torchvision.ops.nms(boxes, scores, 0.5).is_cuda
    image = np.zeros((32, 32, 3), dtype=np.uint8)
    gui = next(
        line.strip()
        for line in cv2.getBuildInformation().splitlines()
        if line.strip().startswith("GUI:")
    )
    assert "NONE" not in gui, gui
    assert cv2.resize(image, (16, 16)).shape == (16, 16, 3)
    assert A.HorizontalFlip(p=1)(image=image)["image"].shape == image.shape
    model = timm.create_model("resnet18", pretrained=False, num_classes=3).cuda().eval()
    with torch.no_grad():
        assert model(torch.randn(1, 3, 64, 64, device="cuda")).shape == (1, 3)
    torch.cuda.synchronize()
    return f"torchvision CUDA NMS, timm forward, OpenCV ({gui}), Albumentations"


check("computer vision", vision)


def huggingface():
    import torch
    from datasets import Dataset
    from transformers import BertConfig, BertModel

    model = BertModel(
        BertConfig(
            vocab_size=32,
            hidden_size=32,
            num_hidden_layers=1,
            num_attention_heads=4,
            intermediate_size=64,
        )
    ).cuda()
    result = model(input_ids=torch.ones(1, 8, dtype=torch.long, device="cuda"))
    assert result.last_hidden_state.shape == (1, 8, 32)
    assert len(Dataset.from_dict({"x": [1, 2]})) == 2
    torch.cuda.synchronize()
    return "tiny Transformer GPU forward and in-memory dataset, no downloads"


check("Hugging Face", huggingface)


def causal():
    import torch
    from causal_conv1d import causal_conv1d_fn
    from causal_conv1d.causal_conv1d_interface import causal_conv1d_ref

    x = torch.randn(2, 16, 32, device="cuda", requires_grad=True)
    weight = torch.randn(16, 4, device="cuda", requires_grad=True)
    result = causal_conv1d_fn(x, weight, activation="silu")
    reference = causal_conv1d_ref(x, weight, activation="silu")
    torch.testing.assert_close(result, reference, atol=1e-4, rtol=1e-4)
    result.square().mean().backward()
    torch.cuda.synchronize()
    assert torch.isfinite(x.grad).all()
    return "native CUDA convolution matched reference; backward passed"


check("causal-conv1d CUDA", causal)


def mamba():
    import torch
    from mamba_ssm import Mamba, Mamba2

    for cls in (Mamba, Mamba2):
        model = cls(d_model=64, d_state=16, d_conv=4, expand=2).cuda()
        x = torch.randn(2, 64, 64, device="cuda", requires_grad=True)
        out = model(x)
        assert out.shape == x.shape and torch.isfinite(out).all()
        out.square().mean().backward()
        torch.cuda.synchronize()
        assert x.grad is not None and torch.isfinite(x.grad).all()
    return "Mamba and Mamba2 GPU forward/backward (including Triton kernels)"


check("Mamba CUDA", mamba)


def kernel():
    from jupyter_client.kernelspec import KernelSpecManager

    spec = KernelSpecManager().get_kernel_spec(args.kernel_name)
    assert spec.display_name == f"Python ({args.kernel_name})"
    assert Path(spec.argv[0]).resolve() == Path(sys.executable).resolve()
    report["jupyter_kernel"] = spec.display_name
    return spec.display_name


check("Jupyter kernel", kernel)
check(
    "pip check",
    lambda: subprocess.check_output(
        [sys.executable, "-m", "pip", "check"], text=True
    ).strip(),
)
report["passed"] = all(c["passed"] for c in report["checks"].values())
if args.report:
    args.report.write_text(json.dumps(report, indent=2) + "\n")
print("\nOVERALL:", "PASS" if report["passed"] else "FAIL", flush=True)
sys.exit(0 if report["passed"] else 1)
