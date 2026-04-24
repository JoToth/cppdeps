# SPDX-License-Identifier: BSD-3-Clause
#
# Copyright (c) 2026, Jozsef Toth
#
# This file is part of cppdeps.
# See LICENSE file for full license text.

if(NOT DEFINED TEST_REPO OR NOT DEFINED TEST_LOCK OR NOT DEFINED TEST_ROOT)
  message(FATAL_ERROR "TEST_REPO, TEST_LOCK and TEST_ROOT are required")
endif()
include("${CMAKE_CURRENT_LIST_DIR}/../cmake/CppDeps.cmake")
set(CPPDEPS_ROOT "${TEST_ROOT}" CACHE PATH "" FORCE)
set(CPPDEPS_LOCKFILE "${TEST_LOCK}" CACHE FILEPATH "" FORCE)
cppdeps_add(NAME testdep GIT_REPOSITORY "${TEST_REPO}" HEAD_OF_BRANCH main BUILD NONE)
cppdeps_resolve_all(WRITE_LOCKFILE)
cppdeps_checkout_all()
