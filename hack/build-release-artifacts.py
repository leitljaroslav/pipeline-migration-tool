#!/usr/bin/env python3
"""Package the current source tree into release artifacts (tar.gz, zip,
SHA256SUMS, JSON manifest). Uses only the standard library so it can run
in a hermetic container build with no extra packages installed.
"""
import hashlib
import json
import re
import sys
import tarfile
import zipfile
from pathlib import Path

NAME = "pipeline-migration-tool"
EXCLUDE_DIRS = {
    ".git",
    ".venv",
    ".tox",
    ".mypy_cache",
    ".pytest_cache",
    "dist",
    "out",
    "hermeto-output",
    "htmlcov",
    "build",
    "local_konflux_files",
    "__pycache__",
}
EXCLUDE_FILES = {"coverage.xml"}


def read_version(source_root: Path) -> str:
    init_py = source_root / "src" / "pipeline_migration" / "__init__.py"
    match = re.search(r'__version__ = "([^"]+)"', init_py.read_text())
    if not match:
        raise SystemExit(f"could not find __version__ in {init_py}")
    return match.group(1)


def included_files(source_root: Path):
    for path in sorted(source_root.rglob("*")):
        if not path.is_file():
            continue
        rel = path.relative_to(source_root)
        if any(part in EXCLUDE_DIRS for part in rel.parts):
            continue
        if rel.name in EXCLUDE_FILES:
            continue
        yield rel


def build_tarball(source_root: Path, files, dest: Path, prefix: str) -> None:
    with tarfile.open(dest, "w:gz") as tar:
        for rel in files:
            tar.add(source_root / rel, arcname=f"{prefix}/{rel}")


def build_zip(source_root: Path, files, dest: Path, prefix: str) -> None:
    with zipfile.ZipFile(dest, "w", zipfile.ZIP_DEFLATED) as zf:
        for rel in files:
            zf.write(source_root / rel, arcname=f"{prefix}/{rel}")


def sha256sum(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit(f"usage: {sys.argv[0]} <output-dir>")

    source_root = Path(".").resolve()
    out_dir = Path(sys.argv[1])
    out_dir.mkdir(parents=True, exist_ok=True)

    version = read_version(source_root)
    prefix = f"{NAME}-{version}"
    files = list(included_files(source_root))

    tarball = out_dir / f"{prefix}.tar.gz"
    zip_path = out_dir / f"{prefix}.zip"
    manifest_path = out_dir / f"{prefix}.json"
    sums_path = out_dir / f"{NAME}_{version}_SHA256SUMS"

    build_tarball(source_root, files, tarball, prefix)
    build_zip(source_root, files, zip_path, prefix)

    manifest = {
        "name": NAME,
        "version": version,
        "artifacts": [tarball.name, zip_path.name],
    }
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")

    with sums_path.open("w") as f:
        for artifact in (tarball, zip_path, manifest_path):
            f.write(f"{sha256sum(artifact)}  {artifact.name}\n")


if __name__ == "__main__":
    main()
