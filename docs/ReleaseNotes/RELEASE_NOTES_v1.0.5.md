# CppDeps v1.0.5 — CTest Isolation Fix

This maintenance release fixes unintended CTest registration when CppDeps is used from another CMake project.

## Fixed

- Restrict CppDeps' internal CTest initialization and test registration to standalone, top-level CppDeps builds.
- Prevent CppDeps' internal regression tests from appearing in consumer projects' CTest test lists when `BUILD_TESTING=ON`.
- Preserve the existing standalone CppDeps test workflow.

## Compatibility

- No changes to the public CppDeps API.
- No changes to bootstrap version selection or dependency resolution.
- Existing consumers can continue using the same bootstrap integration.

## Validation

- The standalone CppDeps test suite contains 11 tests.
- Consumer projects should discover only their own tests, not CppDeps' internal tests.

## Known Limitations

Support for independent dependency build environments, recursive dependency graphs, and multiple simultaneous versions of a dependency remains on the roadmap; these capabilities are outside the scope of v1.0.5.

See [KNOWN_ISSUES.md](https://github.com/JoToth/cppdeps/blob/v1.0.5/KNOWN_ISSUES.md) for documented limitations.

**Full Changelog:** https://github.com/JoToth/cppdeps/compare/v1.0.4...v1.0.5
