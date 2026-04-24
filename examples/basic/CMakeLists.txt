# SPDX-License-Identifier: BSD-3-Clause
#
# Copyright (c) 2026, Jozsef Toth
#
# This file is part of cppdeps.
# See LICENSE file for full license text.


cmake_minimum_required(VERSION 3.20)
project(cppdeps_basic_example LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/CppDeps.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/deps.cmake)

cppdeps_install_all(WRITE_LOCKFILE)

add_executable(cppdeps_basic main.cpp)
target_link_libraries(cppdeps_basic PRIVATE fmt::fmt)
