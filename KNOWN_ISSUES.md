# Known Issues and Limitations — CppDeps v1.0.4 (Release Candidate)

This document describes known limitations and release-verification gaps in the
v1.0.4 release candidate. A potential risk or untested scenario is **not** a
confirmed failure. The bootstrapper branch does not attempt to redesign
transitive dependency resolution or isolated CMake builds.

## 1. Recursive / nested CppDeps use

### Current experience and scope

CppDeps has been used in a multi-level dependency setup (including the Workers
project) without an observed dependency-version collision so far. This is
**not** evidence that arbitrary recursive use, duplicate dependencies, or
multiple versions of the same library are supported.

The current dependency manager maintains a build-wide global registry
(`CPPDEPS_DEPS`) and rejects duplicate dependency names (`cppdeps_add()` uses
an explicit **FAIL** conflict policy). Its default CMake integration adds
sources to the current configuration using `add_subdirectory()`; this shares
CMake target names and relevant configuration state.

CppDeps modules use `include_guard(GLOBAL)`, but this protects repeated
inclusion of the *same module file*. It is not a cross-checkout, cross-version
singleton guarantee if nested projects load different copies of CppDeps.

### Known limitations / unverified cases

- A nested project may declare a dependency name already registered by a parent
  or sibling. The current implementation deliberately errors on duplicates,
  even if the declarations happen to refer to the same revision.
- Building two different revisions of a dependency under a shared name in one
  CMake configure is **not supported by the current v1 conflict model**.
- Nested projects that load different CppDeps source trees/versions have not
  been verified for safe shared registry, module API, or target interactions.
- Distinct CMake configurations (e.g. independently built libraries) may avoid
  some CMake-level collisions, but this release does not implement or validate
  an isolated-build dependency mode.
- `PRIVATE` in `target_link_libraries()` does not guarantee binary symbol
  isolation for static libraries. This is a separate C++/linker concern, not a
  claimed CppDeps bug.

### Workarounds / guidance

For v1.0.4, avoid duplicate dependency names within a single CMake configure,
keep nested dependency selections compatible where possible, and verify the
final link when multiple revisions are involved. Do not assume automatic
multi-version isolation. Consider a dedicated future issue for scoped
dependency identities, nested integration tests, and optional isolated builds.

**Planned improvements:** Dependency graphs and transitive requirements, isolated
CMake builds, and multiple-version support with internal target names are already
listed in the project README roadmap. These are planned v1.x / v2 capabilities,
not newly discovered regressions, and remain outside the scope of the v1.0.4
bootstrapper release.

**Status:** architectural limitation / incomplete test coverage; intentionally
out of scope for the bootstrapper release.

## 2. Bootstrap version selection and refresh

When `CPPDEPS_BOOTSTRAP_GIT_TAG` is empty, the bootstrapper selects the newest
matching stable numeric Git tag during initial configuration and stores the
resolved tag in the CMake cache. Subsequent configurations reuse it unless
an explicit refresh is requested or relevant selection inputs change.

`CPPDEPS_BOOTSTRAP_REFRESH_TAG=ON` is currently a persistent cache option:
**it does not automatically reset to OFF** after a successful refresh. To avoid
re-querying on every later configure, switch it back OFF explicitly.

Version ordering uses CMake's natural sorting of filtered tag names; it is
not a full Semantic Versioning range solver.

**Status:** documented behavior / usability limitation; non-blocking.

## 3. Bootstrap script URL and compatibility with older releases

The short consumer snippet downloads the standalone bootstrap script from the
`main` branch over HTTPS. TLS authenticates the connection to the remote
endpoint but does not pin script contents to a particular release. A newer
script can therefore be downloaded even if the underlying CppDeps version is
pinned. The default snippet does not implement a hash check or explicit
`file(DOWNLOAD STATUS ...)` error handling; in some failure scenarios diagnosis
may occur at the subsequent `include()` step.

The current bootstrapper expects the fetched CppDeps source tree to contain
`cmake/CppDepsBootstrap.cmake`. Older CppDeps tags without that file are not
compatible with this entry point. Do not assume that pinning an arbitrary
older tag works with the latest bootstrap script.

**Status:** bootstrap compatibility and reproducibility limitations.

## 4. Checks before use

The 11 existing CTest cases passed on Linux during release preparation.
This does not establish compatibility with every platform or recursive dependency
graph. Before use, verify:

- The bootstrap script is available at the configured HTTPS URL.
- The selected CppDeps release contains the expected internal entry point
  (`cmake/CppDepsBootstrap.cmake`).
- A fresh consumer project configures successfully with the intended CppDeps
  version in your target environment.

**Status:** recommended consumer verification; no confirmed defect implied.
