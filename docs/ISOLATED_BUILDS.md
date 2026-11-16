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
- The legacy `ARTIFACT` accepts one imported target; `ARTIFACTS` supports multiple explicitly mapped targets.
- CppDeps does **not** infer artifacts, target names, C++ ABI compatibility,
  or transitive static-link dependencies.
- A custom, non-CMake source requires a `BUILD_COMMAND`; absent configure or
  install commands become no-ops.
- Configuration-specific builds are tested with Ninja Multi-Config on Linux;
  cross-compilation toolchains and package-config discovery remain experimental.
- The top-level CMake tests remain independent from isolated dependency tests.
- Dependency Git resolution, checkout and lockfile behavior are unchanged.

## Imported-target contract validation

The legacy `ARTIFACT` declaration publishes one imported library with
`PROVIDES <target>` and `ARTIFACT <file>`. For multiple targets use
`ARTIFACTS <target>=<file> ...`. `PROVIDES` requires one of these artifact
forms; neither artifact form nor `INCLUDE_DIRS` is valid without `PROVIDES`.
Reusing a target name or specifying an artifact that resolves to a directory
is an error.

Both artifact forms and `INCLUDE_DIRS` accept paths relative to the isolated
installation prefix, absolute paths, or the explicit `<SOURCE_DIR>`,
`<BINARY_DIR>` and `<INSTALL_DIR>` placeholders. Resolved paths are normalized;
duplicate include directories are removed. CppDeps creates declared include
directories during configuration because CMake validates imported targets
before the isolated build has installed headers.

Declared artifacts must actually be produced by the isolated build/install
commands. CppDeps does not create library files, infer transitive dependencies,
or independently validate ABI compatibility. Per-configuration artifact
locations can be declared explicitly through `CONFIG_ARTIFACTS`.

## Multiple imported libraries from one isolated build

An isolated dependency may now publish multiple imported libraries using explicit
`target=artifact` mappings. The existing single-target `ARTIFACT` syntax remains
supported without changes.

```cmake
cppdeps_add(
  NAME example
  GIT_REPOSITORY https://example.invalid/example.git
  TAG v1.0
  ISOLATED
  PROVIDES example::core example::utils
  ARTIFACTS
    example::core=lib/libcore.a
    example::utils=lib/libutils.a
  INCLUDE_DIRS include
)
cppdeps_install_all()
```

`ARTIFACTS` must define exactly one entry for each `PROVIDES` target. The mapping
order does not matter. Duplicate, unknown or missing target mappings, duplicate
artifact paths, and mixing `ARTIFACT` with `ARTIFACTS` are configuration errors.
Every artifact path follows the same absolute/install-relative and placeholder
rules as the legacy `ARTIFACT` argument. All mapped artifacts are declared as
`ExternalProject` build byproducts, and each imported target depends on the
same isolated build. `INCLUDE_DIRS` is shared across all provided targets.

Each imported library is currently of type `UNKNOWN IMPORTED`; CppDeps does
not infer inter-library link dependencies. Consumers must explicitly link all
required libraries in an appropriate order. Artifact filenames are toolchain-
specific.

## Arbitrary configuration-specific artifact locations

`CONFIG_ARTIFACTS` describes a *complete*, explicit artifact matrix for the
consumer project's configurations. It accepts `config:target=path` entries,
where configuration names are **not restricted** to `Debug` or `Release`.
For example, `ASan`, `Coverage`, `Profiling` or `CustomOptimized` are valid.

```cmake
cppdeps_add(
  NAME example
  GIT_REPOSITORY https://example.invalid/example.git
  TAG v1.0
  ISOLATED
  PROVIDES example::core example::utils
  CONFIG_ARTIFACTS
    "ASan:example::core=lib/<CONFIG>/libcore.a"
    "ASan:example::utils=lib/<CONFIG>/libutils.a"
    "Coverage:example::core=lib/<CONFIG>/libcore.a"
    "Coverage:example::utils=lib/<CONFIG>/libutils.a"
  INCLUDE_DIRS include
)
```

- Configure Ninja Multi-Config consumers with
  `-DCMAKE_CONFIGURATION_TYPES='ASan;Coverage'`, or configure a single-config
  generator with `-DCMAKE_BUILD_TYPE=ASan`.
- Every `PROVIDES` target must have **one artifact per active configuration**.
  Missing/duplicate mappings, unknown targets, unknown configurations and
  repeated artifact paths are errors. Configuration names are case-insensitive
  for matching CMake's `IMPORTED_LOCATION_<CONFIG>` property names.
- `<CONFIG>` inside a path is replaced with the configuration name from its
  mapping. Other isolated path placeholders remain supported.
- `CONFIG_ARTIFACTS` is mutually exclusive with `ARTIFACT` and `ARTIFACTS`.
  The original API continues to work unchanged when `CONFIG_ARTIFACTS` is absent.
- CppDeps populates `IMPORTED_CONFIGURATIONS` and
  `IMPORTED_LOCATION_<CONFIG>` for each imported target and declares its
  artifact paths as `ExternalProject` build byproducts.
- The isolated CMake project must **actually produce and install** the mapped
  paths for each configuration. This feature does not invent compiler flags or
  guarantee ABI compatibility; e.g. a configuration named `ASan` does not
  automatically enable sanitizers.
- Configuration names are limited to letters, numbers, underscores, dots,
  plus and minus; names differing only in letter case are rejected.
