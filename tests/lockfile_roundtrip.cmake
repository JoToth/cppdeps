# SPDX-License-Identifier: BSD-3-Clause
#
# Copyright (c) 2026, Jozsef Toth
#
# This file is part of cppdeps.
# See LICENSE file for full license text.

include("${CMAKE_CURRENT_LIST_DIR}/git_helpers.cmake")

cppdeps_test_make_repo(repo v1 v2)
set(lock "${CMAKE_CURRENT_BINARY_DIR}/tmp/roundtrip.lock.cmake")
set(root "${CMAKE_CURRENT_BINARY_DIR}/tmp/roundtrip_cppdeps")

# Start from a clean test state. On failure, artifacts are intentionally kept
# for debugging; the next test run removes them here.
file(REMOVE_RECURSE "${root}")
file(REMOVE "${lock}")

# First run: resolve branch head and write lock. The repo is already at v2.
execute_process(
  COMMAND "${CMAKE_COMMAND}" -DTEST_REPO=${repo} -DTEST_LOCK=${lock} -DTEST_ROOT=${root} -P "${CMAKE_CURRENT_LIST_DIR}/resolve_and_lock.cmake"
  RESULT_VARIABLE rc
  OUTPUT_VARIABLE out
  ERROR_VARIABLE err
)
if(NOT rc EQUAL 0)
  message(FATAL_ERROR "initial resolve failed:\n${out}\n${err}")
endif()
file(READ "${lock}" first_lock)
if(NOT first_lock MATCHES "${v2}")
  message(FATAL_ERROR "initial lock did not contain current branch head ${v2}")
endif()

# Advance repo to v3.
cppdeps_test_write("${repo}/value.txt" "v3\n")
cppdeps_test_run_git("${repo}" add .)
cppdeps_test_run_git("${repo}" commit -m v3)
cppdeps_test_run_git("${repo}" rev-parse HEAD)
set(v3 "${CPPDEPS_TEST_GIT_OUT}")

# Strict lock run: should keep v2, not resolve v3.
execute_process(
  COMMAND "${CMAKE_COMMAND}" -DCPPDEPS_STRICT_LOCK=ON -DTEST_REPO=${repo} -DTEST_LOCK=${lock} -DTEST_ROOT=${root} -P "${CMAKE_CURRENT_LIST_DIR}/resolve_and_lock.cmake"
  RESULT_VARIABLE rc2
  OUTPUT_VARIABLE out2
  ERROR_VARIABLE err2
)
if(NOT rc2 EQUAL 0)
  message(FATAL_ERROR "strict lock resolve failed:\n${out2}\n${err2}")
endif()
file(READ "${root}/src/testdep/value.txt" locked_value)
if(NOT locked_value STREQUAL "v2\n")
  message(FATAL_ERROR "strict lock checkout drifted; expected v2, got '${locked_value}', v3 was ${v3}")
endif()

# A lock belonging to another repository must never be reused, even offline.
set(alternate_repo "${repo}-different")
file(REMOVE_RECURSE "${alternate_repo}")
file(COPY "${repo}/" DESTINATION "${alternate_repo}")
execute_process(
  COMMAND "${CMAKE_COMMAND}" -DCPPDEPS_STRICT_LOCK=ON -DTEST_REPO=${alternate_repo} -DTEST_LOCK=${lock} -DTEST_ROOT=${root} -P "${CMAKE_CURRENT_LIST_DIR}/resolve_and_lock.cmake"
  RESULT_VARIABLE mismatch_rc OUTPUT_VARIABLE mismatch_out ERROR_VARIABLE mismatch_err
)
if(mismatch_rc EQUAL 0 OR NOT "${mismatch_out}${mismatch_err}" MATCHES "lockfile repository mismatch")
  message(FATAL_ERROR "Expected lockfile repository mismatch, got: ${mismatch_out} ${mismatch_err}")
endif()
file(REMOVE_RECURSE "${alternate_repo}")

# Successful tests leave no checkout/lockfile footprint behind.
file(REMOVE_RECURSE "${root}")
file(REMOVE "${lock}")

