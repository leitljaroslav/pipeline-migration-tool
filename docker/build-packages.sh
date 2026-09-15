#!/usr/bin/env bash
#
# Build the pipeline-migration-tool Python packages and checksums.
#
# Produces, under /projects/releases:
#   - <name>-<version>.tar.gz  (sdist)
#   - <name>-<version>.zip      (source zip, same contents as the sdist)
#   - SHA256SUMS                (sha256 of both archives, bare filenames)
#
# The wheel is left in /projects/dist for the runtime stage to install.
#
# Intended to run in the builder stage of docker/Dockerfile. setuptools and wheel
# must already be installed; in the hermetic Konflux build they resolve from the
# prefetched deps (no network).
set -euo pipefail

dist_dir="dist"
releases_dir="/projects/releases"

# Building a Python sdist and wheel
python3 -c '''from setuptools import build_meta as b; b.build_sdist("dist"); b.build_wheel("dist")'''

mkdir -p "$releases_dir"

sdist_path=$(ls "$dist_dir"/*.tar.gz)
sdist_name=$(basename "$sdist_path")
base_name=${sdist_name%.tar.gz}

cp "$sdist_path" "$releases_dir/"

# Create a source .zip with the same top-level directory and contents as the sdist.
tmp_dir=$(mktemp -d)
tar -xzf "$sdist_path" -C "$tmp_dir"
(cd "$tmp_dir" && zip -q -r -X "$releases_dir/$base_name.zip" .)
rm -rf "$tmp_dir"

# Generate checksums with bare filenames so `sha256sum -c` works from the dir.
(cd "$releases_dir" && sha256sum "$sdist_name" "$base_name.zip" > SHA256SUMS)
