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

set(CPPDEPS_BOOTSTRAP_URL
  "https://raw.githubusercontent.com/JoToth/cppdeps/main/bootstrap/cppdeps-bootstrap.cmake"
  CACHE STRING
  "URL of the cppdeps standalone bootstrapper"
)

set(_cppdeps_bootstrap_dir "${CMAKE_BINARY_DIR}/_cppdeps")
set(_cppdeps_bootstrap "${_cppdeps_bootstrap_dir}/cppdeps-bootstrap.cmake")

file(MAKE_DIRECTORY "${_cppdeps_bootstrap_dir}")
file(DOWNLOAD
  "${CPPDEPS_BOOTSTRAP_URL}"
  "${_cppdeps_bootstrap}"
  TLS_VERIFY ON
  STATUS _cppdeps_bootstrap_status
)

list(GET _cppdeps_bootstrap_status 0 _cppdeps_bootstrap_status_code)
if(NOT _cppdeps_bootstrap_status_code EQUAL 0)
  list(GET _cppdeps_bootstrap_status 1 _cppdeps_bootstrap_status_message)
  message(FATAL_ERROR
    "Failed to download cppdeps bootstrapper from ${CPPDEPS_BOOTSTRAP_URL}: "
    "${_cppdeps_bootstrap_status_message}"
  )
endif()

include("${_cppdeps_bootstrap}")
include(${CMAKE_CURRENT_LIST_DIR}/deps.cmake)

cppdeps_install_all(WRITE_LOCKFILE)

add_executable(cppdeps_basic main.cpp)
target_link_libraries(cppdeps_basic PRIVATE fmt::fmt)
