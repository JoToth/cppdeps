# Standalone CppDeps remote bootstrapper.
#
# This is the only file a consumer project has to download manually. After it is
# included, it fetches the full cppdeps repository and includes the real
# in-repository bootstrap module from there.
#
# Typical use:
#   set(CPPDEPS_BOOTSTRAP_URL
#     "https://raw.githubusercontent.com/JoToth/cppdeps/main/bootstrap/cppdeps-bootstrap.cmake"
#     CACHE STRING "URL of the cppdeps standalone bootstrapper."
#   )
#   file(DOWNLOAD
#     "${CPPDEPS_BOOTSTRAP_URL}"
#     "${CMAKE_BINARY_DIR}/_cppdeps/cppdeps-bootstrap.cmake"
#     TLS_VERIFY ON
#   )
#   include("${CMAKE_BINARY_DIR}/_cppdeps/cppdeps-bootstrap.cmake")
#
# By default, the bootstrapper fetches the newest remote tag. Override
# CPPDEPS_BOOTSTRAP_GIT_TAG only when pinning a specific tag, branch, or commit.

# SPDX-License-Identifier: BSD-3-Clause
#
# Copyright (c) 2026, Jozsef Toth
#
# This file is part of cppdeps.
# See LICENSE file for full license text.

include_guard(GLOBAL)

cmake_minimum_required(VERSION 3.20)

set(CPPDEPS_BOOTSTRAP_GIT_REPOSITORY
  "https://github.com/JoToth/cppdeps.git"
  CACHE STRING
  "Git repository used by the standalone cppdeps bootstrapper."
)

set(CPPDEPS_BOOTSTRAP_GIT_TAG
  ""
  CACHE STRING
  "Git tag, branch, or commit used by the standalone cppdeps bootstrapper. Empty means latest remote tag."
)

set(CPPDEPS_BOOTSTRAP_GIT_TAG_REGEX
  "^v?[0-9]+(\\.[0-9]+)*([._+-].*)?$"
  CACHE STRING
  "Regex used to select release-like tags when CPPDEPS_BOOTSTRAP_GIT_TAG is empty."
)

set(CPPDEPS_BOOTSTRAP_SOURCE_DIR
  ""
  CACHE PATH
  "Use an existing cppdeps source tree instead of fetching one. Useful for tests, vendoring, and offline builds."
)


function(_cppdeps_bootstrap_tags_from_ls_remote output out_var)
  set(tags)

  string(REGEX MATCHALL "refs/tags/[^\r\n\t ]+" refs "${output}")
  foreach(ref IN LISTS refs)
    string(REGEX REPLACE "^refs/tags/" "" tag "${ref}")

    # Defensive: --refs should already remove annotated-tag deref entries.
    if(tag MATCHES "\\^\\{}$")
      continue()
    endif()

    if(CPPDEPS_BOOTSTRAP_GIT_TAG_REGEX AND NOT tag MATCHES "${CPPDEPS_BOOTSTRAP_GIT_TAG_REGEX}")
      continue()
    endif()

    list(APPEND tags "${tag}")
  endforeach()

  list(REMOVE_DUPLICATES tags)
  set(${out_var} "${tags}" PARENT_SCOPE)
endfunction()

function(_cppdeps_bootstrap_select_latest_tag tags out_var)
  if(NOT tags)
    set(${out_var} "" PARENT_SCOPE)
    return()
  endif()

  set(sorted_tags ${tags})
  list(SORT sorted_tags COMPARE NATURAL ORDER DESCENDING)
  list(GET sorted_tags 0 latest_tag)
  set(${out_var} "${latest_tag}" PARENT_SCOPE)
endfunction()

function(_cppdeps_bootstrap_resolve_git_tag out_var)
  if(CPPDEPS_BOOTSTRAP_GIT_TAG)
    set(${out_var} "${CPPDEPS_BOOTSTRAP_GIT_TAG}" PARENT_SCOPE)
    return()
  endif()

  find_package(Git QUIET)
  if(NOT GIT_FOUND)
    message(FATAL_ERROR
      "CPPDEPS_BOOTSTRAP_GIT_TAG is empty, so the latest remote tag must be resolved, "
      "but git was not found. Set CPPDEPS_BOOTSTRAP_GIT_TAG explicitly."
    )
  endif()

  execute_process(
    COMMAND "${GIT_EXECUTABLE}" ls-remote --tags --refs "${CPPDEPS_BOOTSTRAP_GIT_REPOSITORY}"
    RESULT_VARIABLE ls_remote_result
    OUTPUT_VARIABLE ls_remote_output
    ERROR_VARIABLE ls_remote_error
    OUTPUT_STRIP_TRAILING_WHITESPACE
  )

  if(NOT ls_remote_result EQUAL 0)
    message(FATAL_ERROR
      "Failed to query cppdeps remote tags from ${CPPDEPS_BOOTSTRAP_GIT_REPOSITORY}:\n"
      "${ls_remote_error}"
    )
  endif()

  _cppdeps_bootstrap_tags_from_ls_remote("${ls_remote_output}" resolved_tags)
  _cppdeps_bootstrap_select_latest_tag("${resolved_tags}" resolved_tag)

  if(NOT resolved_tag)
    message(FATAL_ERROR
      "No matching cppdeps release tag found in ${CPPDEPS_BOOTSTRAP_GIT_REPOSITORY}. "
      "Set CPPDEPS_BOOTSTRAP_GIT_TAG explicitly, or adjust CPPDEPS_BOOTSTRAP_GIT_TAG_REGEX."
    )
  endif()

  message(STATUS "cppdeps bootstrap: resolved latest tag: ${resolved_tag}")
  set(${out_var} "${resolved_tag}" PARENT_SCOPE)
endfunction()

function(_cppdeps_bootstrap_include_from_source source_dir)
  if(NOT EXISTS "${source_dir}/cmake/CppDepsBootstrap.cmake")
    message(FATAL_ERROR
      "CPPDEPS bootstrap source does not contain cmake/CppDepsBootstrap.cmake: ${source_dir}"
    )
  endif()

  include("${source_dir}/cmake/CppDepsBootstrap.cmake")
endfunction()

if(CPPDEPS_BOOTSTRAP_SOURCE_DIR)
  _cppdeps_bootstrap_include_from_source("${CPPDEPS_BOOTSTRAP_SOURCE_DIR}")
  return()
endif()

include(FetchContent)

_cppdeps_bootstrap_resolve_git_tag(_cppdeps_bootstrap_resolved_git_tag)

FetchContent_Declare(cppdeps
  GIT_REPOSITORY "${CPPDEPS_BOOTSTRAP_GIT_REPOSITORY}"
  GIT_TAG        "${_cppdeps_bootstrap_resolved_git_tag}"
)

FetchContent_MakeAvailable(cppdeps)

if(NOT DEFINED cppdeps_SOURCE_DIR)
  message(FATAL_ERROR "FetchContent did not define cppdeps_SOURCE_DIR")
endif()

_cppdeps_bootstrap_include_from_source("${cppdeps_SOURCE_DIR}")
