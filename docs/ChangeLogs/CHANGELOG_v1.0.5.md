## [1.0.5] — Change Summary

### Fixed

- Prevented CppDeps internal CTest cases from leaking into consumer projects.
- Restricted CTest initialization and test registration to standalone, top-level CppDeps builds.
- Ensured that consumer projects retain control over their own test suites when `BUILD_TESTING=ON`.

### Compatibility

- No changes to the public CppDeps API.
- No changes to bootstrap version resolution or dependency management.
- All 11 standalone regression tests remain available.

### Validation

- Standalone CppDeps regression suite: 11/11 tests passed.
- Consumer CTest isolation verified on Linux.
