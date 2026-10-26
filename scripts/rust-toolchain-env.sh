#!/usr/bin/env bash
# Shared Rust toolchain selection for the local gates. Source this file, do
# not execute it. The pinned version must stay in sync with rust/rust-toolchain.toml.
if rustup toolchain list | grep -Eq '^stable(-| )' && rustc +stable --version | head -1 | grep -Eq '^rustc 1\.99\.0 '; then
  export RUSTUP_TOOLCHAIN=stable
else
  export RUSTUP_TOOLCHAIN=1.99.0
fi
