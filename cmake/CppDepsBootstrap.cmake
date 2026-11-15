# CppDeps bootstrap entry point.
#
# Include this single file from a vendored/Fetched cppdeps checkout. It loads the
# public CppDeps API and any companion modules using paths relative to this file,
# so users do not need to copy/include each module one-by-one.
#
# Example with FetchContent:
#   include(FetchContent)
#   FetchContent_Declare(cppdeps
#     GIT_REPOSITORY https://github.com/JoToth/cppdeps.git
#     GIT_TAG        v1.0.4
#   )
#   FetchContent_MakeAvailable(cppdeps)
#   include("${cppdeps_SOURCE_DIR}/cmake/CppDepsBootstrap.cmake")

# SPDX-License-Identifier: BSD-3-Clause
#
# Copyright (c) 2026, Jozsef Toth
#
# This file is part of cppdeps.
# See LICENSE file for full license text.

include_guard(GLOBAL)

cmake_minimum_required(VERSION 3.20)

set(CPPDEPS_BOOTSTRAP_DIR "${CMAKE_CURRENT_LIST_DIR}")
include("${CPPDEPS_BOOTSTRAP_DIR}/CppDeps.cmake")
