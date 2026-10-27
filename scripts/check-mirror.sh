#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/rust-toolchain-env.sh
python3 scripts/check-mirror-architecture.py
python3 scripts/check-mirror-architecture-test.py
python3 scripts/check-design-tokens.py
python3 scripts/generate-interface-index.py --check
cargo fmt --manifest-path rust/Cargo.toml --all --check
cargo clippy --manifest-path rust/Cargo.toml --workspace --all-targets --all-features --locked -- -D warnings
cargo test --manifest-path rust/Cargo.toml -p ginkgo_core --no-default-features --locked
cargo test --manifest-path rust/Cargo.toml -p ginkgo_upstream --locked
cargo test --manifest-path rust/Cargo.toml --workspace --locked
cd flutter
flutter pub get
(cd rust_builder/cargokit/build_tool && dart pub get)
flutter analyze
flutter test test
cd ..
# Keep the local baseline as strong as CI: regenerate the FRB bindings when the
# pinned codegen is already installed and fail if anything drifts. CI (bindings
# job) installs the codegen itself; locally we only check when it is present.
if command -v flutter_rust_bridge_codegen >/dev/null 2>&1; then
  # Compare generation with the current tree, not HEAD: uncommitted API changes
  # legitimately change bindings, but a second generation must be identical.
  bindings_before="$(mktemp -d)"
  trap 'rm -rf "$bindings_before"' EXIT
  cp -R flutter/lib/src/rust "$bindings_before/dart"
  cp rust/crates/ginkgo_flutter_bridge/src/frb_generated.rs "$bindings_before/frb_generated.rs"
  bash scripts/generate-mirror-bridge.sh
  diff -r "$bindings_before/dart" flutter/lib/src/rust
  diff "$bindings_before/frb_generated.rs" rust/crates/ginkgo_flutter_bridge/src/frb_generated.rs
else
  echo 'flutter_rust_bridge_codegen not installed locally; FRB drift check runs in CI only.'
fi
