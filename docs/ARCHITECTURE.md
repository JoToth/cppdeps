# Architecture

CppDeps v1 uses a deliberately small pipeline:

```text
manifest -> resolve -> lock -> checkout -> make available
```

## Manifest

A project declares dependencies with `cppdeps_add()`.

The manifest describes:

- dependency identity,
- Git repository,
- selector,
- expected CMake targets,
- build mode,
- CMake options to forward.

## Resolve

Selectors are converted into concrete commits.

Exact selectors:

- `TAG`
- `BRANCH`
- `COMMIT`

Floating selectors:

- `HEAD_OF_BRANCH`
- `HIGHEST_TAG`
- `TAG_REGEX`

## Lock

Resolved commits are written to `deps.lock.cmake`.

The lockfile is intentionally CMake syntax so it can be inspected and included later if needed.

## Checkout

CppDeps keeps checkouts under:

```text
${CMAKE_BINARY_DIR}/_cppdeps/src/<name>/
```

This avoids polluting user-global directories.

## Make available

v1 supports:

- `CMAKE_ADD_SUBDIRECTORY`
- `HEADER_ONLY`
- `NONE`

The default is `CMAKE_ADD_SUBDIRECTORY`.

## Deliberate limitations

v1.0 does not solve:

- transitive dependency graph resolution,
- multiple versions of the same dependency,
- binary caching,
- non-CMake build systems,
- semver constraint solving.

These are future framework layers, not v1 requirements.
