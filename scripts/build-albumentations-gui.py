#!/usr/bin/env python
"""Build GUI OpenCV metadata variants of two checksum-verified upstream wheels.

Only distribution versions and the OpenCV dependency are changed. Python code,
licenses, and other dependencies are preserved. wheel.pack regenerates RECORD.
"""

import argparse
import hashlib
import subprocess
import sys
import tempfile
import urllib.request
import zipfile
from pathlib import Path

SOURCES = {
    "albucore": (
        "0.0.24",
        "https://files.pythonhosted.org/packages/0a/e2/91f145e1f32428e9e1f21f46a7022ffe63d11f549ee55c3b9265ff5207fc/albucore-0.0.24-py3-none-any.whl",
        "adef6e434e50e22c2ee127b7a3e71f2e35fa088bcf54431e18970b62d97d0005",
    ),
    "albumentations": (
        "2.0.8",
        "https://files.pythonhosted.org/packages/8e/64/013409c451a44b61310fb757af4527f3de57fc98a00f40448de28b864290/albumentations-2.0.8-py3-none-any.whl",
        "c4c4259aaf04a7386ad85c7fdcb73c6c7146ca3057446b745cc035805acb1017",
    ),
}
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--output-dir", type=Path, required=True)
args = parser.parse_args()
args.output_dir.mkdir(parents=True, exist_ok=True)

with tempfile.TemporaryDirectory(prefix="ml-base-gui-") as directory:
    root = Path(directory)
    for name, (version, url, digest) in SOURCES.items():
        data = urllib.request.urlopen(url, timeout=60).read()
        if hashlib.sha256(data).hexdigest() != digest:
            raise RuntimeError(f"Upstream checksum mismatch: {name}")
        original = root / url.rsplit("/", 1)[1]
        original.write_bytes(data)
        subprocess.run(
            [sys.executable, "-m", "wheel", "unpack", str(original), "-d", str(root)],
            check=True,
        )
        package_root = root / f"{name}-{version}"
        dist_info = package_root / f"{name}-{version}.dist-info"
        metadata = dist_info / "METADATA"
        contents = metadata.read_text()
        old = "Requires-Dist: opencv-python-headless>=4.9.0.80"
        if contents.count(old) != 1:
            raise RuntimeError(f"Unexpected upstream dependency metadata: {name}")
        contents = contents.replace(old, "Requires-Dist: opencv-python>=4.9.0.80")
        contents = contents.replace(
            f"Version: {version}\n", f"Version: {version}+opencv.gui\n", 1
        )
        metadata.write_text(contents)
        dist_info.rename(package_root / f"{name}-{version}+opencv.gui.dist-info")
        subprocess.run(
            [
                sys.executable,
                "-m",
                "wheel",
                "pack",
                str(package_root),
                "-d",
                str(args.output_dir),
            ],
            check=True,
        )
        # Confirm the code payload stayed byte-for-byte identical.
        rebuilt = args.output_dir / f"{name}-{version}+opencv.gui-py3-none-any.whl"
        with zipfile.ZipFile(original) as before, zipfile.ZipFile(rebuilt) as after:
            for entry in before.namelist():
                if ".dist-info/" not in entry and not entry.endswith("/"):
                    assert before.read(entry) == after.read(
                        entry
                    ), f"Code changed: {entry}"
        print(rebuilt)
