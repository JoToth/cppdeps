# SPDX-License-Identifier: BSD-3-Clause
#
# Copyright (c) 2026, Jozsef Toth
#
# This file is part of cppdeps.
# See LICENSE file for full license text.

function(cppdeps_test_run_git workdir)
  execute_process(
    COMMAND git ${ARGN}
    WORKING_DIRECTORY "${workdir}"
    RESULT_VARIABLE rc
    OUTPUT_VARIABLE out
    ERROR_VARIABLE err
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_STRIP_TRAILING_WHITESPACE
  )
  if(NOT rc EQUAL 0)
    message(FATAL_ERROR "git ${ARGN} failed in ${workdir}: ${err}")
  endif()
  set(CPPDEPS_TEST_GIT_OUT "${out}" PARENT_SCOPE)
endfunction()

function(cppdeps_test_write path content)
  file(WRITE "${path}" "${content}")
endfunction()

function(cppdeps_test_make_repo out_dir out_v1 out_v2)
  set(repo "${CMAKE_CURRENT_BINARY_DIR}/tmp/${out_dir}")
  file(REMOVE_RECURSE "${repo}")
  file(MAKE_DIRECTORY "${repo}")

  # Portable Git initialization: git init -b main requires newer Git.
  # Use the older, widely supported form so tests run on native Linux
  # distributions with older Git versions and on MSYS2/Windows.
  cppdeps_test_run_git("${repo}" init)
  cppdeps_test_run_git("${repo}" checkout -b main)
  cppdeps_test_run_git("${repo}" config user.email test@example.invalid)
  cppdeps_test_run_git("${repo}" config user.name "CppDeps Test")

  cppdeps_test_write("${repo}/CMakeLists.txt" "cmake_minimum_required(VERSION 3.20)\nproject(testdep LANGUAGES NONE)\nadd_library(testdep INTERFACE)\nadd_library(testdep::testdep ALIAS testdep)\n")
  cppdeps_test_write("${repo}/value.txt" "v1\n")
  cppdeps_test_run_git("${repo}" add .)
  cppdeps_test_run_git("${repo}" commit -m v1)
  cppdeps_test_run_git("${repo}" rev-parse HEAD)
  set(v1 "${CPPDEPS_TEST_GIT_OUT}")
  cppdeps_test_run_git("${repo}" tag v1.0.0)

  cppdeps_test_write("${repo}/value.txt" "v2\n")
  cppdeps_test_run_git("${repo}" add .)
  cppdeps_test_run_git("${repo}" commit -m v2)
  cppdeps_test_run_git("${repo}" rev-parse HEAD)
  set(v2 "${CPPDEPS_TEST_GIT_OUT}")
  cppdeps_test_run_git("${repo}" tag v2.0.0)

  set(${out_dir} "${repo}" PARENT_SCOPE)
  set(${out_v1} "${v1}" PARENT_SCOPE)
  set(${out_v2} "${v2}" PARENT_SCOPE)
endfunction()
