#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! flutter_rust_bridge_codegen --version | grep -Eq '^flutter_rust_bridge_codegen 2\.12\.0$'; then
  echo 'Install flutter_rust_bridge_codegen 2.12.0 before generating bindings.' >&2
  exit 1
fi
if rustup toolchain list | grep -Eq '^stable(-| )' && rustc +stable --version | head -1 | grep -Eq '^rustc 1\.99\.0 '; then
  export RUSTUP_TOOLCHAIN=stable
else
  export RUSTUP_TOOLCHAIN=1.99.0
fi
if ! rustfmt --version >/dev/null 2>&1; then
  echo "Install rustfmt for $RUSTUP_TOOLCHAIN before generating bindings." >&2
  exit 1
fi
cd flutter
flutter_rust_bridge_codegen generate
if grep -Fq "stem: 'UNKNOWN'" lib/src/rust/frb_generated.dart; then
  echo 'FRB codegen fell back to UNKNOWN external library stem; check cargo metadata/cache.' >&2
  exit 1
fi
