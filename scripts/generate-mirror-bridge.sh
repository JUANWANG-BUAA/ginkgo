#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! flutter_rust_bridge_codegen --version | rg -q '^flutter_rust_bridge_codegen 2\.12\.0$'; then
  echo 'Install flutter_rust_bridge_codegen 2.12.0 before generating bindings.' >&2
  exit 1
fi
if rustup toolchain list | rg -q '^stable(-| )' && rustc +stable --version | head -1 | rg -q '^rustc 1\.99\.0 '; then
  export RUSTUP_TOOLCHAIN=stable
else
  export RUSTUP_TOOLCHAIN=1.99.0
fi
cd flutter
flutter_rust_bridge_codegen generate
