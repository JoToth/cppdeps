# SPDX-License-Identifier: BSD-3-Clause
#
# Copyright (c) 2026, Jozsef Toth
#
# This file is part of cppdeps.
# See LICENSE file for full license text.

include("${CMAKE_CURRENT_LIST_DIR}/git_helpers.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/../cmake/CppDeps.cmake")

set(CPPDEPS_ROOT "${CMAKE_CURRENT_BINARY_DIR}/tmp/git_integration_cppdeps" CACHE PATH "" FORCE)
set(CPPDEPS_LOCKFILE "${CMAKE_CURRENT_BINARY_DIR}/tmp/git_integration.lock.cmake" CACHE FILEPATH "" FORCE)

# Start from a clean test state. On failure, artifacts are intentionally kept
# for debugging; the next test run removes them here.
file(REMOVE_RECURSE "${CPPDEPS_ROOT}")
file(REMOVE "${CPPDEPS_LOCKFILE}")

cppdeps_test_make_repo(repo v1 v2)

cppdeps_add(
  NAME testdep
  GIT_REPOSITORY "${repo}"
  TAG v1.0.0
  PROVIDES testdep::testdep
  BUILD NONE
)
cppdeps_resolve_all(WRITE_LOCKFILE)
cppdeps_checkout_all()

file(READ "${CPPDEPS_LOCKFILE}" lock_content)
if(NOT lock_content MATCHES "${v1}")
  message(FATAL_ERROR "lockfile did not contain expected v1 commit ${v1}")
endif()

file(READ "${CPPDEPS_ROOT}/src/testdep/value.txt" value)
if(NOT value STREQUAL "v1\n")
  message(FATAL_ERROR "checkout value mismatch: expected v1, got '${value}'")
endif()

# Successful tests leave no checkout/lockfile footprint behind.
file(REMOVE_RECURSE "${CPPDEPS_ROOT}")
file(REMOVE "${CPPDEPS_LOCKFILE}")

