# SPDX-License-Identifier: BSD-3-Clause
#
# Copyright (c) 2026, Jozsef Toth
#
# This file is part of cppdeps.
# See LICENSE file for full license text.

cmake_minimum_required(VERSION 3.20)
include("${CMAKE_CURRENT_LIST_DIR}/../cmake/CppDeps.cmake")

cppdeps_add(
  NAME demo
  PROVIDES demo::demo
  GIT_REPOSITORY https://example.com/demo.git
  COMMIT 0123456789abcdef0123456789abcdef01234567
  BUILD NONE
)

cppdeps_resolve_all(WRITE_LOCKFILE)

if(NOT EXISTS "${CPPDEPS_LOCKFILE}")
  message(FATAL_ERROR "lockfile was not written")
endif()
