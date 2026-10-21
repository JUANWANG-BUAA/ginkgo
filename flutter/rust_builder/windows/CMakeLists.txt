# The Flutter tooling requires that developers have a version of Visual Studio
# installed that includes CMake 3.14 or later. You should not increase this
# version, as doing so will cause the plugin to fail to compile for some
# customers of the plugin.
cmake_minimum_required(VERSION 3.14)

# Project-level configuration.
set(PROJECT_NAME "rust_lib_ginkgo_mirror")
project(${PROJECT_NAME} LANGUAGES CXX)

include("../cargokit/cmake/cargokit.cmake")
# cargokit_cmake_root is resolved across Flutter's generated plugin symlink.
# Resolve from that real package directory rather than counting parent folders
# from .plugin_symlinks (which changes when this plugin is built directly).
get_filename_component(GINKGO_RUST_MANIFEST_DIR
  "${cargokit_cmake_root}/../../../rust/crates/ginkgo_flutter_bridge" ABSOLUTE)
if(NOT EXISTS "${GINKGO_RUST_MANIFEST_DIR}/Cargo.toml")
  message(FATAL_ERROR "Ginkgo Rust manifest not found: ${GINKGO_RUST_MANIFEST_DIR}")
endif()
apply_cargokit(${PROJECT_NAME} "${GINKGO_RUST_MANIFEST_DIR}" ginkgo_flutter_bridge "")

# List of absolute paths to libraries that should be bundled with the plugin.
# This list could contain prebuilt libraries, or libraries created by an
# external build triggered from this build file.
set(rust_lib_ginkgo_mirror_bundled_libraries
  "${${PROJECT_NAME}_cargokit_lib}"
  PARENT_SCOPE
)
