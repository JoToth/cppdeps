# CppDeps

**CppDeps** is a small source dependency framework for CMake.

It is intentionally not a full Conan/vcpkg replacement. The goal of v1.0 is narrower:

- keep dependencies in one declarative CMake manifest,
- resolve Git tags/branches/floating selectors into concrete commits,
- write a lockfile,
- keep source checkouts inside the project build tree,
- expose dependencies to the build through normal CMake targets.

## Status

Version: **v1.0.4**

This repo is GitHub-ready and usable as a starting point. The v1 conflict policy is intentionally strict: duplicate dependency declarations fail.

## Requirements

- CMake 3.20+
- Git 2.20+ available on `PATH` (Git 2.25+ recommended)
- A compiler supported by CMake

Older Git versions may fail with commit-based fetches, tag resolution, or MSYS path handling. CppDeps checks the Git version during CMake configure and fails early with a clear error if it is too old.

## Install

Recommended: download the standalone bootstrapper and let it fetch cppdeps:

```cmake
set(CPPDEPS_BOOTSTRAP_URL
  "https://raw.githubusercontent.com/JoToth/cppdeps/main/bootstrap/cppdeps-bootstrap.cmake"
  CACHE STRING "CppDeps bootstrap URL"
)

file(MAKE_DIRECTORY "${CMAKE_BINARY_DIR}/_cppdeps")
file(DOWNLOAD
  "${CPPDEPS_BOOTSTRAP_URL}"
  "${CMAKE_BINARY_DIR}/_cppdeps/cppdeps-bootstrap.cmake"
  TLS_VERIFY ON
)
include("${CMAKE_BINARY_DIR}/_cppdeps/cppdeps-bootstrap.cmake")
```

By default, the standalone bootstrapper queries the configured Git repository for
stable numeric release tags and fetches the newest matching tag on the first configure. It does **not** track `main`
unless you explicitly ask it to. The selected tag is cached across reconfiguration;
set `CPPDEPS_BOOTSTRAP_REFRESH_TAG=ON` to check for a newer release.

To pin a specific version, branch, or commit:

```cmake
set(CPPDEPS_BOOTSTRAP_GIT_TAG "v1.0.4" CACHE STRING "" FORCE)
```

To use a fork or an internal mirror:

```cmake
set(CPPDEPS_BOOTSTRAP_GIT_REPOSITORY
  "https://git.example.com/tooling/cppdeps.git"
  CACHE STRING
  "Git repository used by the cppdeps bootstrapper"
)
```

The tag filter is configurable as well:

```cmake
set(CPPDEPS_BOOTSTRAP_GIT_TAG_REGEX
  "^v?[0-9]+(\\.[0-9]+)*$"
  CACHE STRING
  "Release tags accepted by the cppdeps bootstrapper"
)
```

Bootstrap configuration variables:

- `CPPDEPS_BOOTSTRAP_URL` — location of the standalone bootstrap script used by
  the consumer project. This variable belongs to the consumer-side download
  snippet, so it can point to GitHub, a fork, or an internal HTTP mirror.
- `CPPDEPS_BOOTSTRAP_GIT_REPOSITORY` — Git repository fetched by the bootstrapper.
- `CPPDEPS_BOOTSTRAP_GIT_TAG` — explicit tag, branch, or commit. When empty, the
  latest matching remote tag is selected.
- `CPPDEPS_BOOTSTRAP_GIT_TAG_REGEX` — regex used when selecting the latest stable tag.
- `CPPDEPS_BOOTSTRAP_REFRESH_TAG` — query the remote again and update the cached tag on configure.
- `CPPDEPS_BOOTSTRAP_SOURCE_DIR` — existing local cppdeps source tree; bypasses
  network fetching entirely.

When using `DEP_<NAME>_SOURCE_DIR` for an individual dependency, CppDeps
skips Git resolution for that dependency, including in offline/strict-lock mode.
Local source overrides do not produce Git commit entries in the lockfile.

For fully offline or vendored use:

```cmake
set(CPPDEPS_BOOTSTRAP_SOURCE_DIR "${CMAKE_CURRENT_LIST_DIR}/external/cppdeps" CACHE PATH "" FORCE)
include("${CMAKE_CURRENT_LIST_DIR}/external/cppdeps/bootstrap/cppdeps-bootstrap.cmake")
```

The fetched repository then loads its internal module entry point:

```cmake
include("${cppdeps_SOURCE_DIR}/cmake/CppDepsBootstrap.cmake")
```

For vendored use without the standalone bootstrapper:

```text
my-project/
  external/cppdeps/
    cmake/CppDepsBootstrap.cmake
    cmake/CppDeps.cmake
  deps.cmake
  CMakeLists.txt
```

Then:

```cmake
include(external/cppdeps/cmake/CppDepsBootstrap.cmake)
```

## Minimal usage

`deps.cmake`:

```cmake
cppdeps_add(
  NAME fmt
  PROVIDES fmt::fmt
  GIT_REPOSITORY https://github.com/fmtlib/fmt.git
  TAG 11.1.4
  BUILD CMAKE_ADD_SUBDIRECTORY
  CMAKE_OPTIONS
    FMT_TEST=OFF
    FMT_DOC=OFF
)
```

`CMakeLists.txt`:

```cmake
cmake_minimum_required(VERSION 3.20)
project(my_app LANGUAGES CXX)

# The bootstrap snippet from the Install section has already loaded cppdeps.
include(deps.cmake)

cppdeps_install_all(WRITE_LOCKFILE)

add_executable(my_app main.cpp)
target_link_libraries(my_app PRIVATE fmt::fmt)
```

Build:

```bash
cmake -S . -B build
cmake --build build
```

CppDeps will create:

```text
build/
  _cppdeps/
    src/fmt/
    build/fmt/
  deps.lock.cmake
```

## Selectors

### Exact selectors

```cmake
TAG v1.2.3
BRANCH main
COMMIT abc123...
```

### Floating selectors

```cmake
HEAD_OF_BRANCH main
HIGHEST_TAG
TAG_REGEX "^v2\\."
```

Floating selectors are resolved to concrete commits before checkout.

## Lockfile

`cppdeps_install_all(WRITE_LOCKFILE)` writes:

```text
build/deps.lock.cmake
```

The lockfile records repository URL, resolved ref, and commit SHA.

By default, if a lockfile exists, CppDeps uses it unless refresh or CLI override is requested.

## CLI overrides

Override a dependency ref:

```bash
cmake -S . -B build -DDEP_FMT_REF=tag:11.1.4
cmake -S . -B build -DDEP_FMT_REF=branch:master
cmake -S . -B build -DDEP_FMT_REF=head:master
cmake -S . -B build -DDEP_FMT_REF=commit:abc123
cmake -S . -B build -DDEP_FMT_REF=highest-tag
cmake -S . -B build -DDEP_FMT_REF=tag-regex:^v2\\.
```

Override with a local source directory:

```bash
cmake -S . -B build -DDEP_FMT_SOURCE_DIR=/home/me/dev/fmt
```

Override names are derived from dependency `NAME`, uppercased and sanitized:

```text
fmt      -> DEP_FMT_REF
my-lib   -> DEP_MY_LIB_REF
```

## Modes

### Offline

```bash
cmake -S . -B build -DCPPDEPS_OFFLINE=ON
```

No remote access. Requires lockfile and local checkout.

### Refresh

```bash
cmake -S . -B build -DCPPDEPS_REFRESH=ON
```

Re-resolves floating refs.

### Strict lock

```bash
cmake -S . -B build -DCPPDEPS_STRICT_LOCK=ON
```

Requires locked commits.

## Build modes

### `CMAKE_ADD_SUBDIRECTORY`

Default mode. The dependency must be a CMake project.

```cmake
BUILD CMAKE_ADD_SUBDIRECTORY
```

CppDeps calls:

```cmake
add_subdirectory(<dep-source> <cppdeps-build-dir> EXCLUDE_FROM_ALL)
```

### `HEADER_ONLY`

Creates an interface target and assumes headers are under `include/`.

```cmake
cppdeps_add(
  NAME myheaders
  PROVIDES myheaders::myheaders
  GIT_REPOSITORY https://example.com/myheaders.git
  TAG v1.0.0
  BUILD HEADER_ONLY
)
```

### `NONE`

Checkout only.

## Conflict policy

v1 supports only:

```text
CPPDEPS_CONFLICT_POLICY=FAIL
```

That means declaring the same dependency name twice is an error.

This is deliberate. C++ multi-version dependency resolution is hard because public CMake targets collide:

```cmake
fmt::fmt
fmt::fmt
```

Future versions may support internal versioned targets such as:

```cmake
cppdeps::fmt__v11
cppdeps::fmt__v9
```

## Design philosophy

CppDeps v1 follows this pipeline:

```text
manifest → resolve → lock → checkout → add_subdirectory/header-only → targets
```

It does not try to guess arbitrary build systems. If a package is not a clean CMake project, it should eventually have a recipe.

## Roadmap

Potential v1.x / v2 items:

- dependency graph and transitive requirements,
- package recipes,
- CMake contract function such as `cppdeps_describe()`,
- `CMAKE_INSTALL` isolated build mode,
- generated graph output,
- better semver constraints,
- multiple-version mode with internal target names,
- archive URL support with checksums.

## License

BSD 3-Clause License

## Known issues

See [KNOWN_ISSUES.md](KNOWN_ISSUES.md), especially the section on recursive / nested CppDeps use and multi-version limitations.
