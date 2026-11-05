from importlib.metadata import version
from pathlib import Path

_version_file = Path(__file__).resolve().parents[2] / "VERSION"

if _version_file.is_file():
    __version__ = _version_file.read_text(encoding="utf-8").strip()
else:
    __version__ = version("pipeline-migration-tool")
