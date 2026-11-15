# v1.0.4 — Change Summary

## Bootstrap workflow
- Preserve `CPPDEPS_VERSION` in consumer CMake scope.
- Resolve the newest stable numeric tag by default.
- Cache the selected tag and allow explicit refresh via `CPPDEPS_BOOTSTRAP_REFRESH_TAG`.
- Keep the consumer download-and-include example short and free of vendored preboot layers.

## Dependency resolution and safety
- Check lockfile repository identity.
- Dereference annotated tags to commit SHAs.
- Protect locally modified checkouts during revision changes.
- Support local source overrides in offline and strict-lock modes.
- Use temporary-file replacement for lockfile writes.

## Verification
- Add Git-fetch bootstrap integration, dirty-checkout, and offline-override regression tests.
- Extend related Git and lockfile test cases.
- 11/11 local Linux CTest cases passed.

## Out of scope
- `main` availability of the standalone bootstrap script is resolved by merge and release, not by a source change in this package.
- Public HTTPS verification and Windows CI must still be checked.

## Known limitations
- Document nested / recursive dependency caveats, persistent refresh behavior, and release verification gaps in [KNOWN_ISSUES.md](KNOWN_ISSUES.md).
