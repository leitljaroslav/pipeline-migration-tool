#!/bin/bash
# Build release artifacts for the pipeline-migration-tool package.
# Produces: tar.gz (sdist), zip (source archive), and SHA256SUMS.
#
# This script is designed to run hermetically (no network, no extra packages).
# It uses only tools available in ubi9/python-312 base image:
# - python with setuptools (from prefetched cache)
# - tar, sha256sum (from coreutils)
# - Python stdlib (shutil.make_archive for zip creation)
#
# Usage: build-packages.sh [OUTPUT_DIR]
#   OUTPUT_DIR: directory to write artifacts to (default: /releases)
#   -h, --help: print this usage message and exit

set -euo pipefail

# Default output directory (matches Konflux release imageBinariesPath)
OUTPUT_DIR="/releases"

# Parse command-line arguments
if [[ $# -gt 0 ]]; then
    case "$1" in
        -h|--help)
            # Print usage and exit
            cat <<EOF
Usage: $0 [OUTPUT_DIR]

Build release artifacts for the pipeline-migration-tool package.

Arguments:
  OUTPUT_DIR    Directory to write artifacts to (default: /releases)

Options:
  -h, --help    Show this help message and exit

Outputs (in OUTPUT_DIR):
  - pipeline_migration_tool-<version>.tar.gz (source distribution)
  - pipeline_migration_tool-<version>.zip    (source archive, same tree)
  - SHA256SUMS                                (checksums of both archives)

Environment:
  SOURCE_DATE_EPOCH  If set, used for reproducible timestamps in archives

This script is hermetic-safe: it uses only setuptools (prefetched) and
coreutils (tar, sha256sum). No network access or extra package installs.
EOF
            exit 0
            ;;
        -*)
            # Unknown option
            echo "Error: Unknown option: $1" >&2
            echo "Run '$0 --help' for usage." >&2
            exit 1
            ;;
        *)
            # Positional argument: output directory
            OUTPUT_DIR="$1"
            ;;
    esac
fi

# Validate OUTPUT_DIR: must be a sane path (no shell metacharacters)
# This prevents injection if OUTPUT_DIR comes from an untrusted source
if [[ ! "$OUTPUT_DIR" =~ ^[a-zA-Z0-9/_.-]+$ ]]; then
    echo "Error: OUTPUT_DIR contains invalid characters: $OUTPUT_DIR" >&2
    echo "Allowed: alphanumeric, /, _, ., -" >&2
    exit 1
fi

# Create OUTPUT_DIR if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Verify OUTPUT_DIR is a writable directory
if [[ ! -d "$OUTPUT_DIR" ]]; then
    echo "Error: OUTPUT_DIR is not a directory: $OUTPUT_DIR" >&2
    exit 1
fi
if [[ ! -w "$OUTPUT_DIR" ]]; then
    echo "Error: OUTPUT_DIR is not writable: $OUTPUT_DIR" >&2
    exit 1
fi

echo "==> Building release artifacts for pipeline-migration-tool"
echo "    Output directory: $OUTPUT_DIR"

# Step 1: Resolve the package version
# The package must be importable from src/ (run from repo root)
echo ""
echo "==> Resolving package version..."
VERSION=$(/venv/bin/python -c "import pipeline_migration as m; print(m.__version__)")

# Validate VERSION is non-empty
if [[ -z "$VERSION" ]]; then
    echo "Error: Failed to resolve package version" >&2
    echo "Ensure the script is run from the repo root with src/ importable" >&2
    exit 1
fi

echo "    Version: $VERSION"

# Step 2: Build the source distribution (sdist) using setuptools backend
# We call the PEP 517 backend directly (setuptools.build_meta.build_sdist)
# to avoid needing the 'build' frontend package (not in prefetched deps).
# The sdist filename follows the pattern: {normalized_name}-{version}.tar.gz
echo ""
echo "==> Building source distribution (sdist)..."

# Build the sdist (setuptools prints build output to stdout/stderr)
/venv/bin/python -c "from setuptools import build_meta as b; b.build_sdist('$OUTPUT_DIR')" >/dev/null

# Construct the expected filename (setuptools normalizes hyphens to underscores)
SDIST_FILENAME="pipeline_migration_tool-$VERSION.tar.gz"

# Verify the sdist was created and is non-empty
SDIST_PATH="$OUTPUT_DIR/$SDIST_FILENAME"
if [[ ! -f "$SDIST_PATH" ]]; then
    echo "Error: sdist not found: $SDIST_PATH" >&2
    exit 1
fi
if [[ ! -s "$SDIST_PATH" ]]; then
    echo "Error: sdist is empty: $SDIST_PATH" >&2
    exit 1
fi

echo "    Created: $SDIST_FILENAME"

# Step 3: Build the zip archive from the sdist's extracted tree
# We extract the sdist, then repackage it as a zip using Python's shutil.
# This ensures the zip and tar.gz contain identical source trees.
echo ""
echo "==> Building zip archive (from sdist tree)..."

# Extract the sdist to OUTPUT_DIR using Python's tarfile module (stdlib, no tar binary needed)
# The tarball extracts to a directory named "pipeline_migration_tool-$VERSION"
/venv/bin/python -c "import tarfile; tarfile.open('$SDIST_PATH').extractall('$OUTPUT_DIR')"

# Verify the extracted directory exists
EXTRACTED_DIR="$OUTPUT_DIR/pipeline_migration_tool-$VERSION"
if [[ ! -d "$EXTRACTED_DIR" ]]; then
    echo "Error: Extracted directory not found: $EXTRACTED_DIR" >&2
    exit 1
fi

# Build the zip using Python's shutil.make_archive (stdlib, no 'zip' binary needed)
# shutil.make_archive(base_name, format, root_dir, base_dir)
#   base_name: output filename without extension
#   format: 'zip'
#   root_dir: directory to chdir into before archiving
#   base_dir: directory to archive (relative to root_dir)
ZIP_BASE="$OUTPUT_DIR/pipeline_migration_tool-$VERSION"
/venv/bin/python -c "import shutil; shutil.make_archive('$ZIP_BASE', 'zip', root_dir='$OUTPUT_DIR', base_dir='pipeline_migration_tool-$VERSION')"

# Verify the zip was created and is non-empty
ZIP_PATH="${ZIP_BASE}.zip"
if [[ ! -f "$ZIP_PATH" ]]; then
    echo "Error: zip not found: $ZIP_PATH" >&2
    exit 1
fi
if [[ ! -s "$ZIP_PATH" ]]; then
    echo "Error: zip is empty: $ZIP_PATH" >&2
    exit 1
fi

echo "    Created: pipeline_migration_tool-$VERSION.zip"

# Clean up the extracted directory (keep only the archives)
rm -rf "$EXTRACTED_DIR"

# Step 4: Generate SHA256 checksums
# Run sha256sum inside OUTPUT_DIR so the paths in SHA256SUMS are basenames
echo ""
echo "==> Generating checksums..."

# Generate checksums using Python's hashlib (stdlib, no sha256sum binary needed)
/venv/bin/python -c "
import hashlib, os
os.chdir('$OUTPUT_DIR')
with open('SHA256SUMS', 'w') as f:
    for fname in ['pipeline_migration_tool-$VERSION.tar.gz', 'pipeline_migration_tool-$VERSION.zip']:
        sha256 = hashlib.sha256(open(fname, 'rb').read()).hexdigest()
        f.write(f'{sha256}  {fname}\n')
"

# Verify SHA256SUMS was created and is non-empty
CHECKSUMS_PATH="$OUTPUT_DIR/SHA256SUMS"
if [[ ! -f "$CHECKSUMS_PATH" ]]; then
    echo "Error: SHA256SUMS not found: $CHECKSUMS_PATH" >&2
    exit 1
fi
if [[ ! -s "$CHECKSUMS_PATH" ]]; then
    echo "Error: SHA256SUMS is empty: $CHECKSUMS_PATH" >&2
    exit 1
fi

echo "    Created: SHA256SUMS"

# Step 5: Print final summary
echo ""
echo "==> Build complete. Artifacts in $OUTPUT_DIR:"
ls -lh "$OUTPUT_DIR"

echo ""
echo "==> Checksums:"
cat "$CHECKSUMS_PATH"

echo ""
echo "==> All artifacts built successfully."
