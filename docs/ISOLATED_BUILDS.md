# Isolated builds (experimental)

CppDeps can build a dependency in a **separate CMake configuration** using
CMake `ExternalProject`. This is an experimental feature implementation.

## Mode selection

- The existing `CMAKE_ADD_SUBDIRECTORY` mode remains the default.
- Specifying `ISOLATED` or `BUILD ISOLATED` opts into isolated CMake configure/build/install.
- Specifying any of `CONFIGURE_COMMAND`, `BUILD_COMMAND`, or `INSTALL_COMMAND`
  selects isolated mode automatically.
- Mixing custom commands or `ISOLATED` with `BUILD HEADER_ONLY`, `BUILD NONE`
  or `BUILD CMAKE_ADD_SUBDIRECTORY` is an error.

## Automatic CMake build

```cmake
cppdeps_add(
  NAME example
  GIT_REPOSITORY https://example.invalid/example.git
  TAG v1.0
  ISOLATED
  PROVIDES example::example
  ARTIFACT lib/libexample.a
  INCLUDE_DIRS include
)
cppdeps_install_all()
target_link_libraries(my_exe PRIVATE example::example)
```

`ARTIFACT` refers to a relative path under the dependency's **isolated install
prefix**, or an absolute path. It is mandatory when `PROVIDES` is present in
isolated mode. `INCLUDE_DIRS` paths are also relative to the install prefix
unless absolute. For portability, choose the correct artifact filename for the
platform/toolchain.

## Custom commands

A custom command implies isolated mode, even when `ISOLATED` is omitted:

```cmake
cppdeps_add(
  NAME legacy
  GIT_REPOSITORY https://example.invalid/legacy.git
  TAG v2.0
  CONFIGURE_COMMAND <SOURCE_DIR>/configure --prefix=<INSTALL_DIR>
  BUILD_COMMAND make -C <SOURCE_DIR>
  INSTALL_COMMAND make -C <SOURCE_DIR> install
)
```

Commands are **CMake argument lists**, not shell scripts. Shell features such as
pipes and `&&` are not interpreted; use a dedicated script if required. The
underlying `ExternalProject` supports `<SOURCE_DIR>`, `<BINARY_DIR>`, and
`<INSTALL_DIR>` placeholders. `CMAKE_OPTIONS KEY=VALUE ...` is forwarded as
`-DKEY=VALUE` to isolated CMake projects.

## Important limitations

- Isolated builds run at **build time**, not at consumer configure time.
- Up to **one imported target** can be declared using `PROVIDES` and `ARTIFACT`.
- CppDeps does **not** infer artifacts, target names, C++ ABI compatibility,
  or transitive static-link dependencies.
- A custom, non-CMake source requires a `BUILD_COMMAND`; absent configure or
  install commands become no-ops.
- Multi-config builds, cross-compilation toolchains and package-config based
  discovery need additional integration testing before production use.
- The top-level CMake tests remain independent from isolated dependency tests.
- Dependency Git resolution, checkout and lockfile behavior are unchanged.
