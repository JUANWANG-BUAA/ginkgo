#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Reuse a matching installed stable toolchain; do not download it twice.
if rustup toolchain list | grep -Eq '^stable(-| )' && rustc +stable --version | head -1 | grep -Eq '^rustc 1\.99\.0 '; then
  export RUSTUP_TOOLCHAIN=stable
else
  export RUSTUP_TOOLCHAIN=1.99.0
fi
cargo fmt --manifest-path rust/Cargo.toml --all --check
cargo clippy --manifest-path rust/Cargo.toml --workspace --all-targets --all-features --locked -- -D warnings
cargo test --manifest-path rust/Cargo.toml --workspace --locked
cd flutter
(cd rust_builder/cargokit/build_tool && dart pub get)
flutter analyze
flutter test test
