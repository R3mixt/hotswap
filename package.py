"""Test and package Hot Swap from any checkout location.

Run ``python package.py`` from the repository root, or pass ``--output PATH``.
Only the explicit runtime manifest and selected documentation enter the addon
archive. Development sources travel in a separate source archive.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
from pathlib import Path
import re
import shutil
import subprocess
import sys
from tempfile import TemporaryDirectory
import zipfile


ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / "KeybindOptimizer"
TOC = "KeybindOptimizer.toc"
# LibraryUI extends UI after its helpers exist; Launcher loads last.
MODULES = (
    "Core.lua", "Diagnostics.lua", "API.lua", "Protection.lua", "Profiles.lua", "Macros.lua", "Items.lua",
    "LibraryData.lua", "Availability.lua", "TalentBindings.lua", "Library.lua", "NativeBars.lua", "Planner.lua",
    "Engine.lua", "AvailabilityEngine.lua", "Presets.lua", "ActionBars.lua", "CurrentBindings.lua", "ItemsUI.lua", "UI.lua", "LibraryUI.lua",
    "HoverBindingsUI.lua", "SettingsUI.lua", "Launcher.lua",
)
RUNTIME_FILES = (TOC, *MODULES, "README.md")
SOURCE_FILES = (
    "package.py", "requirements-dev.txt", ".github/workflows/validate.yml",
    ".github/workflows/curseforge.yml", "CONTRIBUTING.md",
    "publishing/upload_curseforge.py", "publishing/curseforge.json",
    ".gitattributes", "build_library_data.py", "catalog-classification-input.json",
    "classification-source.json", "talent-classification-source.json",
    "forever-talent-classification-source.json", "ui-qa/capture.py", "ui-qa/render.ps1",
    "publishing/project.json", "publishing/curseforge-description.md", "publishing/changelog-1.0.4.txt",
    "publishing/logo.svg", "publishing/logo.png", "publishing/build-logo.ps1",
)


def read_manifest(source: Path) -> tuple[str, tuple[str, ...]]:
    """Reject missing, unexpected, reordered, or traversing TOC entries."""
    toc = (source / TOC).read_text(encoding="utf-8-sig")
    entries = tuple(line.strip() for line in toc.splitlines()
                    if line.strip() and not line.lstrip().startswith("#"))
    if entries != MODULES:
        raise ValueError("TOC module order does not match package.py's runtime allowlist")
    match = re.search(r"^## Version:\s*([A-Za-z0-9][A-Za-z0-9._-]*)\s*$", toc, re.M)
    if not match:
        raise ValueError("TOC needs a filename-safe Version field")
    for name in RUNTIME_FILES:
        path = source / name
        if not path.is_file() or path.is_symlink():
            raise ValueError(f"Missing or linked runtime file: {name}")
    return match.group(1), entries


def run_validation() -> tuple[str, int]:
    """Run current sources; a stale success report never authorizes a build."""
    packaging = subprocess.run(
        [sys.executable, "-m", "unittest", "discover", "-s", str(ROOT / "tests"),
         "-p", "test_package.py", "-v"],
        cwd=ROOT, text=True, encoding="utf-8", errors="replace",
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
    )
    packaging_match = re.search(r"Ran ([1-9]\d*) tests? in", packaging.stdout)
    if packaging.returncode or not packaging_match:
        raise RuntimeError("Current packaging regression suite did not pass:\n" + packaging.stdout)
    print(f"Packaging regression tests: {packaging_match[1]} passed")
    result = subprocess.run(
        [sys.executable, str(ROOT / "tests" / "run_tests.py")],
        cwd=ROOT, text=True, encoding="utf-8", errors="replace",
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
    )
    match = re.search(r"(\d+)/(\d+) tests passed \(actual Lua 5\.1; mocked WoW APIs\)\.", result.stdout)
    if result.returncode or not match or int(match[1]) != int(match[2]) or int(match[2]) == 0:
        raise RuntimeError("Current Lua 5.1 regression suite did not pass:\n" + result.stdout)
    print(match.group(0))
    return packaging.stdout + "\n" + result.stdout, int(match[2])


def copy_files(source: Path, destination: Path, names: tuple[str, ...]) -> None:
    for name in names:
        target = destination / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source / name, target)


def copy_documentation(destination: Path) -> None:
    for path in sorted((ROOT / "docs").glob("*.md")):
        if not path.is_symlink():
            destination.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, destination / path.name)


def validation_report(total: int) -> str:
    date = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    return f"""# Automated validation

Built: {date}

- {total}/{total} regression scenarios passed using the actual addon modules in Lua 5.1 with mocked WoW APIs.
- The TOC matches the explicit {len(MODULES)}-module runtime allowlist and dependency order.
- Both ZIP archives were checked for exact expected file lists and CRC integrity before publication.
- The CurseForge ZIP has one addon root, its matching TOC directly inside it, and every TOC load file present.
- The Python packaging regression suite passed before building the archives.
- Packaging uses fresh temporary staging; previous release files and local Python dependencies are excluded.

These checks do not launch WoW. In-game protected actions, taint, actual input routing, casting and server-specific behavior still require client testing. See compatibility.md. The complete test log and regression sources are included in the separate source archive.
"""


def write_archive(directory: Path, archive: Path, prefix: str) -> None:
    files = sorted(path for path in directory.rglob("*") if path.is_file())
    expected = {f"{prefix}/{path.relative_to(directory).as_posix()}" for path in files}
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as bundle:
        for path in files:
            bundle.write(path, f"{prefix}/{path.relative_to(directory).as_posix()}")
    with zipfile.ZipFile(archive) as bundle:
        names = bundle.namelist()
        if len(names) != len(expected) or set(names) != expected or bundle.testzip() is not None:
            raise ValueError(f"ZIP verification failed: {archive.name}")
        toc_name = f"{prefix}/" + (TOC if prefix == "KeybindOptimizer" else f"KeybindOptimizer/{TOC}")
        toc = bundle.read(toc_name).decode("utf-8-sig")
        modules = tuple(line.strip() for line in toc.splitlines()
                        if line.strip() and not line.lstrip().startswith("#"))
        if modules != MODULES:
            raise ValueError(f"Packaged TOC order changed: {archive.name}")


def validate_runtime_archive(archive: Path) -> str:
    """Validate the installable ZIP layout, independently of its filename.

    Developer archives intentionally have an extra wrapper. They must never
    pass this check if accidentally selected as the runtime upload artifact.
    """
    root = Path(TOC).stem
    toc_name = f"{root}/{TOC}"
    with zipfile.ZipFile(archive) as bundle:
        names = bundle.namelist()
        if (not names or len(names) != len(set(names))
                or any("\\" in name or name.startswith("/")
                       or ".." in name.split("/") for name in names)):
            raise ValueError(f"Invalid runtime ZIP paths: {archive.name}")
        if ({name.split("/", 1)[0] for name in names} != {root}
                or any("/" not in name for name in names)):
            raise ValueError(f"Runtime ZIP must contain only the {root}/ addon root: {archive.name}")
        files = {entry.filename for entry in bundle.infolist() if not entry.is_dir()}
        if toc_name not in files:
            raise ValueError(f"Runtime ZIP is missing the immediate matching TOC: {toc_name}")
        toc = bundle.read(toc_name).decode("utf-8-sig")
        entries = tuple(line.strip() for line in toc.splitlines()
                        if line.strip() and not line.lstrip().startswith("#"))
        for entry in entries:
            relative = entry.replace("\\", "/")
            if (relative.startswith("/") or ":" in relative
                    or any(part in {"", ".", ".."} for part in relative.split("/"))):
                raise ValueError(f"Unsafe packaged TOC load path: {entry}")
            if f"{root}/{relative}" not in files:
                raise ValueError(f"Runtime ZIP is missing a TOC load file: {entry}")
        if entries != MODULES:
            raise ValueError(f"Packaged TOC order changed: {archive.name}")
    return toc_name


def checked_output(output: Path) -> tuple[Path, Path]:
    """Resolve the replacement boundary before any recursive cleanup can occur."""
    output = output.resolve()
    installed = output / "KeybindOptimizer"
    source_root = SOURCE.resolve()
    if (installed.resolve() == source_root or output == source_root
            or source_root in output.parents):
        raise ValueError("Output must not replace or link to the source addon directory")
    if installed.resolve() != installed or installed.is_symlink() or installed.is_junction():
        raise ValueError("Output addon directory must stay inside output and cannot be a link or junction")
    if installed.exists() and not installed.is_dir():
        raise ValueError("Output KeybindOptimizer path must be a directory")
    # Do not traverse a nested junction while checking an old distribution.
    # Refuse links instead of relying on platform-specific rmtree behavior.
    pending = [installed] if installed.exists() else []
    while pending:
        for path in pending.pop().iterdir():
            if path.is_symlink() or path.is_junction() or not path.resolve().is_relative_to(installed):
                raise ValueError(f"Output addon contains a link or junction: {path}")
            if path.is_dir():
                pending.append(path)
    return output, installed


def package(output: Path) -> tuple[Path, Path]:
    version, _ = read_manifest(SOURCE)
    output, installed = checked_output(output)
    for name in (*SOURCE_FILES, "LICENSE"):
        if not (ROOT / name).is_file() or (ROOT / name).is_symlink():
            raise ValueError(f"Missing or linked release source: {name}")
    log, total = run_validation()
    output.mkdir(parents=True, exist_ok=True)
    archive_names = (f"HotSwap-{version}-CurseForge.zip",
                     f"HotSwap-{version}-developer-source-NOT-FOR-UPLOAD.zip")
    # Staging in output keeps replacement on one volume. Move old loose files
    # aside only after both ZIPs verify, and roll that move back on failure.
    with TemporaryDirectory(prefix=".hotswap-build-", dir=output) as temporary:
        stage = Path(temporary)
        addon = stage / "KeybindOptimizer"
        copy_files(SOURCE, addon, RUNTIME_FILES)
        copy_files(ROOT, addon, ("LICENSE",))
        copy_documentation(addon / "docs")
        report = validation_report(total)
        (addon / "docs").mkdir(exist_ok=True)
        (addon / "docs" / "validation.md").write_text(report, encoding="utf-8")
        source = stage / "source"
        copy_files(SOURCE, source / "KeybindOptimizer", RUNTIME_FILES)
        copy_documentation(source / "docs")
        (source / "docs").mkdir(exist_ok=True)
        (source / "docs" / "validation.md").write_text(report, encoding="utf-8")
        (source / "test-results.txt").write_text(log, encoding="utf-8")
        copy_files(ROOT, source, (*SOURCE_FILES, "LICENSE"))
        for name in ("README.md", "CHANGELOG.md", ".gitignore"):
            if (ROOT / name).is_file():
                copy_files(ROOT, source, (name,))
        for path in sorted((ROOT / "tests").iterdir()):
            if path.is_file() and not path.is_symlink() and path.suffix in {".lua", ".py"}:
                copy_files(ROOT, source, (path.relative_to(ROOT).as_posix(),))
        write_archive(addon, stage / archive_names[0], "KeybindOptimizer")
        toc_path = validate_runtime_archive(stage / archive_names[0])
        write_archive(source, stage / archive_names[1], f"HotSwap-{version}-source")
        checked_output(output)  # Recheck after tests/build, immediately before moving old files.
        previous = stage / "previous-addon"
        if installed.exists():
            installed.rename(previous)
        try:
            addon.rename(installed)
        except OSError:
            if previous.exists():
                previous.rename(installed)
            raise
        for name in archive_names:
            archive = stage / name
            digest = hashlib.sha256(archive.read_bytes()).hexdigest()
            checksum = stage / (name.removesuffix(".zip") + ".sha256")
            checksum.write_text(f"{digest}  {name}\n", encoding="ascii")
            archive.replace(output / name)
            checksum.replace(output / checksum.name)
            print(f"Packaged {output / name} ({(output / name).stat().st_size:,} bytes)")
    print(f"TOC: {len(MODULES)} modules; ZIP integrity: passed; SHA-256 manifests written")
    print(f"CurseForge upload structure: passed; TOC: {toc_path}")
    return output / archive_names[0], output / archive_names[1]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "dist",
                        help="Output directory (default: repository/dist; relative paths use the current directory)")
    args = parser.parse_args()
    try:
        package(args.output)
    except (OSError, ValueError, RuntimeError) as exc:
        print(f"Package failed: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
