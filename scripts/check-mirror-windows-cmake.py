#!/usr/bin/env python3
"""Check Windows FFI CMake wiring on any host; this does not build Windows."""

from __future__ import annotations

import argparse
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tempfile


def cmake_path(path: Path) -> str:
    return path.as_posix().replace('"', '\\"')


def check_plugin(plugin: Path, *, through_symlink: bool) -> None:
    expected_manifest = plugin.parent.parent / "rust/crates/ginkgo_flutter_bridge"
    if not (expected_manifest / "Cargo.toml").is_file():
        raise RuntimeError(f"Expected Rust workspace missing: {expected_manifest}")
    with tempfile.TemporaryDirectory(prefix="ginkgo cmake ") as directory:
        source = Path(directory) / "source"
        source.mkdir()
        plugin_source = plugin
        if through_symlink:
            plugin_source = source / "flutter/ephemeral/.plugin_symlinks/rust_lib_ginkgo_mirror"
            plugin_source.parent.mkdir(parents=True)
            plugin_source.symlink_to(plugin, target_is_directory=True)
        (source / "CMakeLists.txt").write_text(
            "cmake_minimum_required(VERSION 3.14)\n"
            "project(ginkgo_windows_wiring LANGUAGES CXX)\n"
            # Exercise a multi-configuration DLL output without pretending that
            # the host compiler is Windows or requiring the Flutter engine.
            'set(CMAKE_CONFIGURATION_TYPES "Debug;Release")\n'
            'set(CMAKE_SHARED_MODULE_PREFIX "")\n'
            'set(CMAKE_SHARED_MODULE_SUFFIX ".dll")\n'
            'set(FLUTTER_TARGET_PLATFORM "windows-x64")\n'
            f'add_subdirectory("{cmake_path(plugin_source / "windows")}" plugin)\n'
            'file(GENERATE OUTPUT "${CMAKE_BINARY_DIR}/bundle-$<CONFIG>.txt" '
            'CONTENT "${rust_lib_ginkgo_mirror_bundled_libraries}")\n',
            encoding="utf-8",
        )
        for configuration in ("Debug", "Release"):
            build = Path(directory) / f"build-{configuration}"
            result = subprocess.run(
                [
                    "cmake", "-S", str(source), "-B", str(build),
                    f"-DCMAKE_BUILD_TYPE={configuration}", "--trace-expand",
                ],
                check=False,
                capture_output=True,
                text=True,
            )
            if result.returncode:
                raise RuntimeError(result.stdout + result.stderr)
            # CMake expands the actual environment argument passed to Cargokit.
            manifest_argument = (
                f"CARGOKIT_MANIFEST_DIR={expected_manifest.resolve().as_posix()}"
            )
            if '-E make_directory ${CARGOKIT_OUTPUT_DIR}' in result.stderr:
                raise RuntimeError('Cargokit output directory was not expanded')
            output_argument = f"-E make_directory {build.as_posix()}/plugin/$<CONFIG>"
            if output_argument not in result.stderr:
                raise RuntimeError('Cargokit must create the output directory before DLL copy')
            if manifest_argument not in result.stderr:
                raise RuntimeError(
                    f"Cargokit did not receive the real manifest: {manifest_argument}"
                )
            bundled = (build / f"bundle-{configuration}.txt").read_text()
            expected_dll = build / f"plugin/{configuration}/ginkgo_flutter_bridge.dll"
            if bundled != expected_dll.as_posix():
                raise RuntimeError(f"Wrong bundled DLL: {bundled}; expected {expected_dll}")
        mode = "Flutter plugin symlink" if through_symlink else "direct plugin"
        print(f"{mode}: manifest and Debug/Release DLL bundle paths passed")


def check_cold_copy(plugin: Path) -> None:
    """Build the real CMake copy target with a synthetic build-tool stand-in."""
    with tempfile.TemporaryDirectory(prefix="ginkgo cmake cold copy ") as directory:
        fixture = Path(directory)
        fixture_plugin = fixture / "flutter/rust_builder"
        (fixture_plugin / "windows").mkdir(parents=True)
        (fixture_plugin / "cargokit/cmake").mkdir(parents=True)
        for relative in (
            "windows/CMakeLists.txt",
            "cargokit/cmake/cargokit.cmake",
            "cargokit/cmake/resolve_symlinks.ps1",
        ):
            shutil.copyfile(plugin / relative, fixture_plugin / relative)
        manifest = fixture / "rust/crates/ginkgo_flutter_bridge"
        manifest.mkdir(parents=True)
        (manifest / "Cargo.toml").write_text(
            '[package]\nname = "synthetic_copy_fixture"\nversion = "0.0.0"\n',
            encoding="utf-8",
        )
        synthetic_bytes = b"SYNTHETIC BUILD COPY; NOT A WINDOWS BINARY\n"
        (manifest / "synthetic.dll").write_bytes(synthetic_bytes)

        # Replace only the Rust build tool inside this isolated fixture. The
        # stand-in performs BuildCMake's file-copy operation without creating
        # the destination directory. CMake must create it before invoking us.
        # No Windows binary is compiled or executed by this check.
        copier = fixture_plugin / "cargokit/synthetic_copy.py"
        copier.write_text(
            "import os\nfrom pathlib import Path\nimport shutil\n"
            'source = Path(os.environ["CARGOKIT_MANIFEST_DIR"]) / "synthetic.dll"\n'
            'destination = Path(os.environ["CARGOKIT_OUTPUT_DIR"]) / '
            '"ginkgo_flutter_bridge.dll"\n'
            "shutil.copyfile(source, destination)\n",
            encoding="utf-8",
        )
        (fixture_plugin / "cargokit/run_build_tool.sh").write_text(
            f"#!/bin/sh\nexec {shlex.quote(sys.executable)} {shlex.quote(str(copier))}\n",
            encoding="utf-8",
        )
        (fixture_plugin / "cargokit/run_build_tool.cmd").write_text(
            f'@echo off\n"{sys.executable}" "{copier}"\nexit /b %ERRORLEVEL%\n',
            encoding="utf-8",
        )
        source = fixture / "source"
        source.mkdir()
        (source / "CMakeLists.txt").write_text(
            "cmake_minimum_required(VERSION 3.14)\n"
            "project(ginkgo_synthetic_copy LANGUAGES CXX)\n"
            'set(CMAKE_CONFIGURATION_TYPES "Debug;Release")\n'
            'set(CMAKE_SHARED_MODULE_PREFIX "")\n'
            'set(CMAKE_SHARED_MODULE_SUFFIX ".dll")\n'
            'set(FLUTTER_TARGET_PLATFORM "windows-x64")\n'
            f'add_subdirectory("{cmake_path(fixture_plugin / "windows")}" plugin)\n',
            encoding="utf-8",
        )
        for configuration in ("Debug", "Release"):
            build = fixture / f"build-{configuration}"
            for command in (
                [
                    "cmake", "-S", str(source), "-B", str(build),
                    f"-DCMAKE_BUILD_TYPE={configuration}",
                ],
                [
                    "cmake", "--build", str(build), "--config", configuration,
                    "--target", "rust_lib_ginkgo_mirror_cargokit",
                ],
            ):
                result = subprocess.run(command, capture_output=True, text=True)
                if result.returncode:
                    raise RuntimeError(result.stdout + result.stderr)
            copied = build / f"plugin/{configuration}/ginkgo_flutter_bridge.dll"
            if copied.read_bytes() != synthetic_bytes:
                raise RuntimeError(f"Synthetic DLL copy differs: {copied}")
            print(f"{configuration}: cold CMake target and synthetic DLL copy passed")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--plugin-directory",
        type=Path,
        default=Path(__file__).resolve().parent.parent / "flutter/rust_builder",
    )
    arguments = parser.parse_args()
    plugin = arguments.plugin_directory.resolve()
    for through_symlink in (False, True):
        check_plugin(plugin, through_symlink=through_symlink)
    check_cold_copy(plugin)


if __name__ == "__main__":
    main()
