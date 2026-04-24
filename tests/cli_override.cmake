# SPDX-License-Identifier: BSD-3-Clause
#
# Copyright (c) 2026, Jozsef Toth
#
# This file is part of cppdeps.
# See LICENSE file for full license text.

include("${CMAKE_CURRENT_LIST_DIR}/git_helpers.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/../cmake/CppDeps.cmake")

set(CPPDEPS_ROOT "${CMAKE_CURRENT_BINARY_DIR}/tmp/override_cppdeps" CACHE PATH "" FORCE)
set(CPPDEPS_LOCKFILE "${CMAKE_CURRENT_BINARY_DIR}/tmp/override.lock.cmake" CACHE FILEPATH "" FORCE)

cppdeps_test_make_repo(repo v1 v2)
set(DEP_TESTDEP_REF "tag:v2.0.0" CACHE STRING "" FORCE)
cppdeps_add(NAME testdep GIT_REPOSITORY "${repo}" TAG v1.0.0 BUILD NONE)
cppdeps_resolve_all(WRITE_LOCKFILE)
cppdeps_checkout_all()

file(READ "${CPPDEPS_ROOT}/src/testdep/value.txt" value)
if(NOT value STREQUAL "v2\n")
  message(FATAL_ERROR "CLI override did not select v2; got '${value}'")
endif()
