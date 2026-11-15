# CppDeps v1.0.4 — Release Notes (Draft)

CppDeps v1.0.4 introduces a standalone remote bootstrap workflow and hardens dependency resolution for more predictable CMake-based builds.

## Highlights

- Bootstrap CppDeps from a small HTTPS download-and-include snippet without vendoring additional files into consumer repositories.
- Automatically select the newest stable, numeric release tag on first configuration, or pin a tag, branch, or commit explicitly.
- Cache the automatically selected tag across reconfigurations; opt into refreshing via `CPPDEPS_BOOTSTRAP_REFRESH_TAG=ON`.
- Expose `CPPDEPS_VERSION` to the consuming CMake project after bootstrap.

## Reliability and correctness

- Validate dependency lockfile repository identity before reusing locked revisions.
- Resolve annotated Git tags to commit SHAs.
- Protect dependency working trees from unsafe revision switching when local modifications are present.
- Allow local source overrides without Git resolution in offline and strict-lock configurations.
- Write lockfiles using a temporary file followed by replacement.

## Documentation and tests

- Restore the concise, TLS-verified bootstrap download example in the README and basic example.
- Extend automated coverage for Git bootstrap, stable tag selection, checkout safety, lockfiles, and offline local overrides.
- Local Linux verification: 11/11 CTest tests passed.

## Known issues and limitations

See [KNOWN_ISSUES.md](KNOWN_ISSUES.md) for recursive/nested CppDeps usage,
version-refresh behavior, bootstrap compatibility, and outstanding verification.
Multi-version recursive dependency support is **not claimed** for v1.0.4.

## Publication and usage checks

- Merge the bootstrapper into `main`, then create the `v1.0.4` tag on the intended commit and publish the GitHub Release.
- Before use, verify that the public HTTPS bootstrap URL is accessible and a clean consumer project configures successfully.
- The current local test evidence is Linux-only (11/11 CTest cases passed); Windows/MSYS2 validation is not a release prerequisite.

> This document describes a release candidate. The public release has not been published by this package-generation step.
