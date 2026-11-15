# CppDeps v1.0.4
# A small source dependency framework for CMake.
#
# Public API:
#   cppdeps_add(...)
#   cppdeps_resolve_all([WRITE_LOCKFILE])
#   cppdeps_checkout_all()
#   cppdeps_make_available_all()
#   cppdeps_install_all([WRITE_LOCKFILE])
#
# Supported selectors:
#   TAG <tag>
#   BRANCH <branch>
#   COMMIT <sha>
#   HEAD_OF_BRANCH <branch>
#   HIGHEST_TAG
#   TAG_REGEX <regex> [SORT VERSION_DESC|LEX_DESC]
#
# Supported build modes:
#   CMAKE_ADD_SUBDIRECTORY (default)
#   HEADER_ONLY
#   NONE
#   ISOLATED (standalone CMake configure/build/install)
#   Custom CONFIGURE_COMMAND, BUILD_COMMAND or INSTALL_COMMAND implies ISOLATED

# SPDX-License-Identifier: BSD-3-Clause
#
# Copyright (c) 2026, Jozsef Toth
#
# This file is part of cppdeps.
# See LICENSE file for full license text.


include_guard(GLOBAL)

cmake_minimum_required(VERSION 3.20)

set(CPPDEPS_VERSION "1.0.4")

if(NOT DEFINED CPPDEPS_ROOT)
  set(CPPDEPS_ROOT "${CMAKE_BINARY_DIR}/_cppdeps" CACHE PATH "CppDeps working directory")
endif()

set(CPPDEPS_LOCKFILE "${CMAKE_BINARY_DIR}/deps.lock.cmake" CACHE FILEPATH "CppDeps lockfile path")
set(CPPDEPS_OFFLINE OFF CACHE BOOL "Do not contact remotes; use lockfile/local checkout only")
set(CPPDEPS_REFRESH OFF CACHE BOOL "Refresh floating refs and update selected commits")
set(CPPDEPS_STRICT_LOCK OFF CACHE BOOL "Require locked commits and do not resolve floating refs")
set(CPPDEPS_CONFLICT_POLICY "FAIL" CACHE STRING "Conflict policy: FAIL")
set_property(CACHE CPPDEPS_CONFLICT_POLICY PROPERTY STRINGS FAIL)
set(CPPDEPS_DEBUG_PATHS OFF CACHE BOOL "Print CppDeps path normalization diagnostics")

set(CPPDEPS_MINIMUM_GIT_VERSION "2.20.0" CACHE STRING "Minimum Git version required by CppDeps")

function(_cppdeps_require_git)
  execute_process(
    COMMAND git --version
    RESULT_VARIABLE rc
    OUTPUT_VARIABLE out
    ERROR_VARIABLE err
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_STRIP_TRAILING_WHITESPACE
  )

  if(NOT rc EQUAL 0)
    _cppdeps_fatal("Git is required but was not found on PATH. ${err}")
  endif()

  string(REGEX MATCH "[0-9]+\\.[0-9]+(\\.[0-9]+)?" git_version "${out}")
  if(NOT git_version)
    _cppdeps_fatal("Could not parse Git version from: '${out}'")
  endif()

  if(git_version VERSION_LESS CPPDEPS_MINIMUM_GIT_VERSION)
    _cppdeps_fatal("CppDeps requires Git >= ${CPPDEPS_MINIMUM_GIT_VERSION}; found ${git_version}. Please upgrade Git. Git 2.25+ is recommended.")
  endif()
endfunction()

set_property(GLOBAL PROPERTY CPPDEPS_DEPS "")

function(_cppdeps_msg text)
  message(STATUS "[cppdeps] ${text}")
endfunction()

function(_cppdeps_fatal text)
  message(FATAL_ERROR "[cppdeps] ${text}")
endfunction()

_cppdeps_require_git()

function(_cppdeps_norm_name out name)
  string(TOUPPER "${name}" upper)
  string(REGEX REPLACE "[^A-Z0-9]" "_" upper "${upper}")
  set(${out} "${upper}" PARENT_SCOPE)
endfunction()

function(_cppdeps_slug out value)
  string(REGEX REPLACE "[^A-Za-z0-9_.-]" "_" slug "${value}")
  set(${out} "${slug}" PARENT_SCOPE)
endfunction()
function(_cppdeps_debug_path raw normalized kind)
  if(CPPDEPS_DEBUG_PATHS)
    message(STATUS "[cppdeps][path] ${kind}: '${raw}' -> '${normalized}'")
  endif()
endfunction()

function(_cppdeps_is_remote_like out value)
  # URLs and SCP-like Git remotes are not filesystem paths and must not be
  # canonicalized as paths. Examples:
  #   https://github.com/org/repo.git
  #   ssh://git@example.com/org/repo.git
  #   git@github.com:org/repo.git
  set(v "${value}")
  if(v MATCHES "^[A-Za-z][A-Za-z0-9+.-]*://" OR v MATCHES "^[^/@]+@[^:]+:.+")
    set(${out} TRUE PARENT_SCOPE)
  else()
    set(${out} FALSE PARENT_SCOPE)
  endif()
endfunction()

function(_cppdeps_normalize_path out value)
  set(v "${value}")
  string(REPLACE "\\" "/" v "${v}")

  # MSYS/Cygwin drive form: /d/projects/x -> D:/projects/x
  if(v MATCHES "^/([A-Za-z])/(.*)$")
    set(drive "${CMAKE_MATCH_1}")
    string(TOUPPER "${drive}" drive)
    set(v "${drive}:/${CMAKE_MATCH_2}")
  endif()

  if(EXISTS "${v}")
    file(REAL_PATH "${v}" v)
  else()
    cmake_path(NORMAL_PATH v)
  endif()

  string(REPLACE "\\" "/" v "${v}")
  string(REGEX REPLACE "/+$" "" v "${v}")
  _cppdeps_debug_path("${value}" "${v}" "local")
  set(${out} "${v}" PARENT_SCOPE)
endfunction()

function(_cppdeps_canonical_repo out value)
  set(v "${value}")
  string(REPLACE "\\" "/" v "${v}")
  _cppdeps_is_remote_like(is_remote "${v}")
  if(is_remote)
    string(REGEX REPLACE "/+$" "" v "${v}")
    _cppdeps_debug_path("${value}" "${v}" "remote")
    set(${out} "${v}" PARENT_SCOPE)
  else()
    _cppdeps_normalize_path(v_norm "${v}")
    set(${out} "${v_norm}" PARENT_SCOPE)
  endif()
endfunction()

function(_cppdeps_paths_equal out lhs rhs)
  _cppdeps_normalize_path(lhs_norm "${lhs}")
  _cppdeps_normalize_path(rhs_norm "${rhs}")
  if(lhs_norm STREQUAL rhs_norm)
    set(${out} TRUE PARENT_SCOPE)
  else()
    set(${out} FALSE PARENT_SCOPE)
  endif()
endfunction()

function(_cppdeps_repo_equal out lhs rhs)
  _cppdeps_canonical_repo(lhs_norm "${lhs}")
  _cppdeps_canonical_repo(rhs_norm "${rhs}")
  if(lhs_norm STREQUAL rhs_norm)
    set(${out} TRUE PARENT_SCOPE)
  else()
    set(${out} FALSE PARENT_SCOPE)
  endif()
endfunction()

function(_cppdeps_git output_var)
  execute_process(
    COMMAND git ${ARGN}
    WORKING_DIRECTORY "${CMAKE_BINARY_DIR}"
    RESULT_VARIABLE rc
    OUTPUT_VARIABLE out
    ERROR_VARIABLE err
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_STRIP_TRAILING_WHITESPACE
  )
  if(NOT rc EQUAL 0)
    _cppdeps_fatal("git ${ARGN} failed: ${err}")
  endif()
  set(${output_var} "${out}" PARENT_SCOPE)
endfunction()

function(_cppdeps_git_in dir output_var)
  execute_process(
    COMMAND git ${ARGN}
    WORKING_DIRECTORY "${dir}"
    RESULT_VARIABLE rc
    OUTPUT_VARIABLE out
    ERROR_VARIABLE err
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_STRIP_TRAILING_WHITESPACE
  )
  if(NOT rc EQUAL 0)
    _cppdeps_fatal("git -C ${dir} ${ARGN} failed: ${err}")
  endif()
  set(${output_var} "${out}" PARENT_SCOPE)
endfunction()

function(_cppdeps_git_try_in dir result_var output_var)
  execute_process(
    COMMAND git ${ARGN}
    WORKING_DIRECTORY "${dir}"
    RESULT_VARIABLE rc
    OUTPUT_VARIABLE out
    ERROR_VARIABLE err
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_STRIP_TRAILING_WHITESPACE
  )
  set(${result_var} "${rc}" PARENT_SCOPE)
  set(${output_var} "${out}" PARENT_SCOPE)
endfunction()

function(cppdeps_add)
  set(options HIGHEST_TAG ISOLATED)
  set(oneValueArgs NAME GIT_REPOSITORY TAG BRANCH COMMIT HEAD_OF_BRANCH TAG_REGEX SORT BUILD ARTIFACT)
  set(multiValueArgs PROVIDES CMAKE_OPTIONS CONFIGURE_COMMAND BUILD_COMMAND INSTALL_COMMAND INCLUDE_DIRS)
  cmake_parse_arguments(DEP "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  if(NOT DEP_NAME)
    _cppdeps_fatal("cppdeps_add requires NAME")
  endif()
  if(NOT DEP_GIT_REPOSITORY)
    _cppdeps_fatal("cppdeps_add(${DEP_NAME}) requires GIT_REPOSITORY")
  endif()
  # An explicit isolated flag or any custom build-phase command selects the
  # standalone build backend. Keep the existing in-tree default otherwise.
  if(DEP_ISOLATED OR DEP_CONFIGURE_COMMAND OR DEP_BUILD_COMMAND OR DEP_INSTALL_COMMAND)
    if(DEP_BUILD AND NOT DEP_BUILD STREQUAL "ISOLATED")
      _cppdeps_fatal("${DEP_NAME}: isolated commands/ISOLATED conflict with BUILD '${DEP_BUILD}'")
    endif()
    set(DEP_BUILD "ISOLATED")
  elseif(NOT DEP_BUILD)
    set(DEP_BUILD "CMAKE_ADD_SUBDIRECTORY")
  endif()
  if((DEP_ARTIFACT OR DEP_INCLUDE_DIRS) AND NOT DEP_BUILD STREQUAL "ISOLATED")
    _cppdeps_fatal("${DEP_NAME}: ARTIFACT and INCLUDE_DIRS require isolated build")
  endif()
  if(NOT DEP_SORT)
    set(DEP_SORT "VERSION_DESC")
  endif()

  set(selector_count 0)
  foreach(k TAG BRANCH COMMIT HEAD_OF_BRANCH TAG_REGEX)
    if(DEP_${k})
      math(EXPR selector_count "${selector_count}+1")
    endif()
  endforeach()
  if(DEP_HIGHEST_TAG)
    math(EXPR selector_count "${selector_count}+1")
  endif()
  if(NOT selector_count EQUAL 1)
    _cppdeps_fatal("cppdeps_add(${DEP_NAME}) requires exactly one selector: TAG, BRANCH, COMMIT, HEAD_OF_BRANCH, HIGHEST_TAG, or TAG_REGEX")
  endif()

  get_property(deps GLOBAL PROPERTY CPPDEPS_DEPS)
  list(FIND deps "${DEP_NAME}" existing_index)
  if(NOT existing_index EQUAL -1)
    _cppdeps_fatal("dependency '${DEP_NAME}' is declared more than once. v1 conflict policy is FAIL.")
  endif()
  list(APPEND deps "${DEP_NAME}")
  set_property(GLOBAL PROPERTY CPPDEPS_DEPS "${deps}")

  _cppdeps_norm_name(norm "${DEP_NAME}")
  set_property(GLOBAL PROPERTY "CPPDEPS_${norm}_REPO" "${DEP_GIT_REPOSITORY}")
  set_property(GLOBAL PROPERTY "CPPDEPS_${norm}_PROVIDES" "${DEP_PROVIDES}")
  set_property(GLOBAL PROPERTY "CPPDEPS_${norm}_BUILD" "${DEP_BUILD}")
  set_property(GLOBAL PROPERTY "CPPDEPS_${norm}_SORT" "${DEP_SORT}")
  set_property(GLOBAL PROPERTY "CPPDEPS_${norm}_CMAKE_OPTIONS" "${DEP_CMAKE_OPTIONS}")
  foreach(k CONFIGURE_COMMAND BUILD_COMMAND INSTALL_COMMAND INCLUDE_DIRS ARTIFACT)
    set_property(GLOBAL PROPERTY "CPPDEPS_${norm}_${k}" "${DEP_${k}}")
  endforeach()

  foreach(k TAG BRANCH COMMIT HEAD_OF_BRANCH TAG_REGEX)
    if(DEP_${k})
      set_property(GLOBAL PROPERTY "CPPDEPS_${norm}_SELECTOR" "${k}")
      set_property(GLOBAL PROPERTY "CPPDEPS_${norm}_SELECTOR_VALUE" "${DEP_${k}}")
    endif()
  endforeach()
  if(DEP_HIGHEST_TAG)
    set_property(GLOBAL PROPERTY "CPPDEPS_${norm}_SELECTOR" "HIGHEST_TAG")
    set_property(GLOBAL PROPERTY "CPPDEPS_${norm}_SELECTOR_VALUE" "")
  endif()
endfunction()

function(_cppdeps_load_lock_for name expected_repo out_commit out_ref)
  set(commit "")
  set(ref "")
  set(locked_repo "")
  if(EXISTS "${CPPDEPS_LOCKFILE}")
    file(STRINGS "${CPPDEPS_LOCKFILE}" lines REGEX "^set\\(CPPDEPS_LOCK_${name}_")
    foreach(line IN LISTS lines)
      if(line MATCHES "^set\\(CPPDEPS_LOCK_${name}_COMMIT \"([^\"]*)\"\\)")
        set(commit "${CMAKE_MATCH_1}")
      elseif(line MATCHES "^set\\(CPPDEPS_LOCK_${name}_REF \"([^\"]*)\"\\)")
        set(ref "${CMAKE_MATCH_1}")
      elseif(line MATCHES "^set\\(CPPDEPS_LOCK_${name}_REPO \"([^\"]*)\"\\)")
        set(locked_repo "${CMAKE_MATCH_1}")
      endif()
    endforeach()
  endif()
  if(commit AND NOT "${locked_repo}" STREQUAL "${expected_repo}")
    _cppdeps_fatal("${name}: lockfile repository mismatch (locked '${locked_repo}', requested '${expected_repo}'). Use a fresh lockfile or explicitly refresh it.")
  endif()
  set(${out_commit} "${commit}" PARENT_SCOPE)
  set(${out_ref} "${ref}" PARENT_SCOPE)
endfunction()

function(_cppdeps_resolve_ref name)
  _cppdeps_norm_name(norm "${name}")
  get_property(repo GLOBAL PROPERTY "CPPDEPS_${norm}_REPO")
  get_property(selector GLOBAL PROPERTY "CPPDEPS_${norm}_SELECTOR")
  get_property(value GLOBAL PROPERTY "CPPDEPS_${norm}_SELECTOR_VALUE")
  get_property(sort GLOBAL PROPERTY "CPPDEPS_${norm}_SORT")

  # A local source override is authoritative and never requires remote resolution.
  if(DEFINED DEP_${norm}_SOURCE_DIR AND NOT "${DEP_${norm}_SOURCE_DIR}" STREQUAL "")
    return()
  endif()

  _cppdeps_load_lock_for("${norm}" "${repo}" locked_commit locked_ref)

  if(CPPDEPS_STRICT_LOCK OR CPPDEPS_OFFLINE)
    if(locked_commit)
      set_property(GLOBAL PROPERTY "CPPDEPS_${norm}_RESOLVED_COMMIT" "${locked_commit}")
      set_property(GLOBAL PROPERTY "CPPDEPS_${norm}_RESOLVED_REF" "${locked_ref}")
      return()
    endif()
    _cppdeps_fatal("${name}: lockfile has no commit and CPPDEPS_STRICT_LOCK/CPPDEPS_OFFLINE is enabled")
  endif()

  _cppdeps_norm_name(cli_prefix "${name}")
  if(DEFINED DEP_${cli_prefix}_REF)
    set(cli_ref "${DEP_${cli_prefix}_REF}")
    if(cli_ref MATCHES "^tag:(.+)$")
      set(selector "TAG")
      set(value "${CMAKE_MATCH_1}")
    elseif(cli_ref MATCHES "^branch:(.+)$")
      set(selector "BRANCH")
      set(value "${CMAKE_MATCH_1}")
    elseif(cli_ref MATCHES "^head:(.+)$")
      set(selector "HEAD_OF_BRANCH")
      set(value "${CMAKE_MATCH_1}")
    elseif(cli_ref MATCHES "^commit:(.+)$")
      set(selector "COMMIT")
      set(value "${CMAKE_MATCH_1}")
    elseif(cli_ref STREQUAL "highest-tag")
      set(selector "HIGHEST_TAG")
      set(value "")
    elseif(cli_ref MATCHES "^tag-regex:(.+)$")
      set(selector "TAG_REGEX")
      set(value "${CMAKE_MATCH_1}")
    else()
      _cppdeps_fatal("${name}: invalid CLI override DEP_${cli_prefix}_REF='${cli_ref}'")
    endif()
    _cppdeps_msg("${name}: using CLI override DEP_${cli_prefix}_REF=${cli_ref}")
  endif()

  if(locked_commit AND NOT CPPDEPS_REFRESH AND NOT DEFINED DEP_${cli_prefix}_REF)
    set_property(GLOBAL PROPERTY "CPPDEPS_${norm}_RESOLVED_COMMIT" "${locked_commit}")
    set_property(GLOBAL PROPERTY "CPPDEPS_${norm}_RESOLVED_REF" "${locked_ref}")
    return()
  endif()

  if(selector STREQUAL "COMMIT")
    set(commit "${value}")
    set(ref "${value}")
  elseif(selector STREQUAL "TAG")
    _cppdeps_git(out ls-remote "${repo}" "refs/tags/${value}^{}")
    if(NOT out)
      _cppdeps_git(out ls-remote "${repo}" "refs/tags/${value}")
    endif()
    if(NOT out MATCHES "^([0-9a-fA-F]+)[ \t]+(.+)$")
      _cppdeps_fatal("${name}: tag '${value}' not found")
    endif()
    set(commit "${CMAKE_MATCH_1}")
    set(ref "refs/tags/${value}")
  elseif(selector STREQUAL "BRANCH" OR selector STREQUAL "HEAD_OF_BRANCH")
    _cppdeps_git(out ls-remote "${repo}" "refs/heads/${value}")
    if(NOT out MATCHES "^([0-9a-fA-F]+)[ \t]+(.+)$")
      _cppdeps_fatal("${name}: branch '${value}' not found")
    endif()
    set(commit "${CMAKE_MATCH_1}")
    set(ref "refs/heads/${value}")
  elseif(selector STREQUAL "HIGHEST_TAG" OR selector STREQUAL "TAG_REGEX")
    if(sort STREQUAL "VERSION_DESC")
      _cppdeps_git(out ls-remote --tags --sort=-version:refname "${repo}")
    elseif(sort STREQUAL "LEX_DESC")
      _cppdeps_git(out ls-remote --tags "${repo}")
    else()
      _cppdeps_fatal("${name}: invalid SORT '${sort}'")
    endif()
    string(REPLACE "\n" ";" lines "${out}")
    set(chosen_sha "")
    set(chosen_ref "")
    foreach(line IN LISTS lines)
      if(line MATCHES "\\^\\{\\}$")
        continue()
      endif()
      if(line MATCHES "^([0-9a-fA-F]+)[ \t]+refs/tags/(.+)$")
        set(sha "${CMAKE_MATCH_1}")
        set(tag "${CMAKE_MATCH_2}")
        if(selector STREQUAL "HIGHEST_TAG" OR tag MATCHES "${value}")
          set(chosen_sha "${sha}")
          set(chosen_ref "refs/tags/${tag}")
          break()
        endif()
      endif()
    endforeach()
    if(NOT chosen_sha)
      _cppdeps_fatal("${name}: no matching tag found for selector ${selector} '${value}'")
    endif()
    # `ls-remote --tags` already contains peeled lines for annotated tags.
    # Use the exact matching ref instead of issuing a second, potentially
    # ambiguous Git query. Lightweight tags have no peeled line.
    set(peeled_ref "${chosen_ref}^{}")
    foreach(line IN LISTS lines)
      if(line MATCHES "^([0-9a-fA-F]+)[ \t]+(.+)$")
        set(candidate_sha "${CMAKE_MATCH_1}")
        set(candidate_ref "${CMAKE_MATCH_2}")
        if(candidate_ref STREQUAL peeled_ref)
          set(chosen_sha "${candidate_sha}")
          break()
        endif()
      endif()
    endforeach()
    set(commit "${chosen_sha}")
    set(ref "${chosen_ref}")
  else()
    _cppdeps_fatal("${name}: unknown selector '${selector}'")
  endif()

  set_property(GLOBAL PROPERTY "CPPDEPS_${norm}_RESOLVED_COMMIT" "${commit}")
  set_property(GLOBAL PROPERTY "CPPDEPS_${norm}_RESOLVED_REF" "${ref}")
  _cppdeps_msg("${name}: ${selector} '${value}' -> ${commit}")
endfunction()

function(cppdeps_resolve_all)
  set(options WRITE_LOCKFILE)
  cmake_parse_arguments(ARG "${options}" "" "" ${ARGN})
  get_property(deps GLOBAL PROPERTY CPPDEPS_DEPS)
  foreach(name IN LISTS deps)
    _cppdeps_resolve_ref("${name}")
  endforeach()
  if(ARG_WRITE_LOCKFILE)
    cppdeps_write_lockfile()
  endif()
endfunction()

function(cppdeps_write_lockfile)
  get_property(deps GLOBAL PROPERTY CPPDEPS_DEPS)
  set(_cppdeps_lock_tmp "${CPPDEPS_LOCKFILE}.tmp")
  file(WRITE "${_cppdeps_lock_tmp}" "# Generated by CppDeps ${CPPDEPS_VERSION}. Do not edit by hand.\n")
  foreach(name IN LISTS deps)
    _cppdeps_norm_name(norm "${name}")
    get_property(repo GLOBAL PROPERTY "CPPDEPS_${norm}_REPO")
    get_property(commit GLOBAL PROPERTY "CPPDEPS_${norm}_RESOLVED_COMMIT")
    get_property(ref GLOBAL PROPERTY "CPPDEPS_${norm}_RESOLVED_REF")
    if(NOT commit)
      # Local source overrides intentionally do not enter the Git lockfile.
      continue()
    endif()
    file(APPEND "${_cppdeps_lock_tmp}" "set(CPPDEPS_LOCK_${norm}_REPO \"${repo}\")\n")
    file(APPEND "${_cppdeps_lock_tmp}" "set(CPPDEPS_LOCK_${norm}_REF \"${ref}\")\n")
    file(APPEND "${_cppdeps_lock_tmp}" "set(CPPDEPS_LOCK_${norm}_COMMIT \"${commit}\")\n\n")
  endforeach()
  file(RENAME "${_cppdeps_lock_tmp}" "${CPPDEPS_LOCKFILE}")
  _cppdeps_msg("wrote lockfile: ${CPPDEPS_LOCKFILE}")
endfunction()

function(_cppdeps_checkout_one name)
  _cppdeps_norm_name(norm "${name}")
  get_property(repo GLOBAL PROPERTY "CPPDEPS_${norm}_REPO")
  get_property(commit GLOBAL PROPERTY "CPPDEPS_${norm}_RESOLVED_COMMIT")
  get_property(ref GLOBAL PROPERTY "CPPDEPS_${norm}_RESOLVED_REF")

  if(DEFINED DEP_${norm}_SOURCE_DIR)
    set(src "${DEP_${norm}_SOURCE_DIR}")
    if(NOT IS_DIRECTORY "${src}")
      _cppdeps_fatal("${name}: DEP_${norm}_SOURCE_DIR is not a directory: ${src}")
    endif()
    set_property(GLOBAL PROPERTY "CPPDEPS_${norm}_SOURCE_DIR" "${src}")
    _cppdeps_msg("${name}: using local source override ${src}")
    return()
  endif()
  if(NOT commit)
    _cppdeps_fatal("${name}: not resolved. Call cppdeps_resolve_all() first.")
  endif()


  set(base "${CPPDEPS_ROOT}/src/${name}")
  file(MAKE_DIRECTORY "${CPPDEPS_ROOT}/src")

  if(NOT EXISTS "${base}/.git")
    if(CPPDEPS_OFFLINE)
      _cppdeps_fatal("${name}: source checkout missing in offline mode: ${base}")
    endif()
    _cppdeps_msg("${name}: cloning ${repo}")
    _cppdeps_git(dummy clone "${repo}" "${base}")
  else()
    _cppdeps_git_in("${base}" current_url config --get remote.origin.url)
    _cppdeps_repo_equal(same_repo "${current_url}" "${repo}")
    if(NOT same_repo)
      _cppdeps_fatal("${name}: existing checkout remote URL differs. Expected '${repo}', got '${current_url}'")
    endif()
  endif()

  _cppdeps_git_try_in("${base}" rc out cat-file -e "${commit}^{commit}")
  if(NOT rc EQUAL 0)
    if(CPPDEPS_OFFLINE)
      _cppdeps_fatal("${name}: commit ${commit} missing in offline mode")
    endif()
    _cppdeps_msg("${name}: fetching ${ref}")
    if(ref MATCHES "^refs/tags/")
      _cppdeps_git_in("${base}" dummy fetch --tags --prune origin)
    elseif(ref MATCHES "^refs/heads/(.+)$")
      _cppdeps_git_in("${base}" dummy fetch --prune origin "${CMAKE_MATCH_1}")
    else()
      _cppdeps_git_in("${base}" dummy fetch origin "${commit}")
    endif()
  endif()

  _cppdeps_git_in("${base}" current_head rev-parse HEAD)
  if(NOT current_head STREQUAL commit)
    _cppdeps_git_in("${base}" dirty_status status --porcelain --untracked-files=all)
    if(NOT "${dirty_status}" STREQUAL "")
      _cppdeps_fatal("${name}: refusing to switch dirty dependency checkout '${base}'. Preserve or discard local changes manually.")
    endif()
    _cppdeps_git_in("${base}" dummy checkout --detach "${commit}")
  endif()
  set_property(GLOBAL PROPERTY "CPPDEPS_${norm}_SOURCE_DIR" "${base}")
endfunction()

function(cppdeps_checkout_all)
  get_property(deps GLOBAL PROPERTY CPPDEPS_DEPS)
  foreach(name IN LISTS deps)
    _cppdeps_checkout_one("${name}")
  endforeach()
endfunction()

function(_cppdeps_apply_cmake_options name)
  _cppdeps_norm_name(norm "${name}")
  get_property(opts GLOBAL PROPERTY "CPPDEPS_${norm}_CMAKE_OPTIONS")
  foreach(pair IN LISTS opts)
    if(pair MATCHES "^([^=]+)=(.*)$")
      set("${CMAKE_MATCH_1}" "${CMAKE_MATCH_2}" CACHE INTERNAL "CppDeps option for ${name}" FORCE)
    else()
      _cppdeps_fatal("${name}: CMAKE_OPTIONS entries must use KEY=VALUE, got '${pair}'")
    endif()
  endforeach()
endfunction()

# Isolated builds are deliberately build-time operations. Their artifacts must
# be declared explicitly; we do not guess target names or static-link closure.
function(_cppdeps_make_isolated name src provides)
  include(ExternalProject)
  _cppdeps_norm_name(norm "${name}")
  set(binary_dir "${CPPDEPS_ROOT}/isolated/build/${name}")
  set(install_dir "${CPPDEPS_ROOT}/isolated/install/${name}")
  file(MAKE_DIRECTORY "${binary_dir}" "${install_dir}")

  foreach(k CONFIGURE_COMMAND BUILD_COMMAND INSTALL_COMMAND INCLUDE_DIRS ARTIFACT)
    get_property(value GLOBAL PROPERTY "CPPDEPS_${norm}_${k}")
    set(custom_${k} "${value}")
  endforeach()
  get_property(options GLOBAL PROPERTY "CPPDEPS_${norm}_CMAKE_OPTIONS")
  set(cmake_args "-DCMAKE_INSTALL_PREFIX:PATH=<INSTALL_DIR>")
  foreach(pair IN LISTS options)
    if(NOT pair MATCHES "^([^=]+)=(.*)$")
      _cppdeps_fatal("${name}: CMAKE_OPTIONS must use KEY=VALUE, got '${pair}'")
    endif()
    list(APPEND cmake_args "-D${CMAKE_MATCH_1}=${CMAKE_MATCH_2}")
  endforeach()

  # ExternalProject's defaults are CMake-native. For non-CMake sources every
  # phase must be custom, except optional configure/install no-op phases.
  if(NOT EXISTS "${src}/CMakeLists.txt")
    if(NOT custom_BUILD_COMMAND)
      _cppdeps_fatal("${name}: isolated non-CMake project requires BUILD_COMMAND")
    endif()
    if(NOT custom_CONFIGURE_COMMAND)
      set(custom_CONFIGURE_COMMAND "${CMAKE_COMMAND};-E;true")
    endif()
    if(NOT custom_INSTALL_COMMAND)
      set(custom_INSTALL_COMMAND "${CMAKE_COMMAND};-E;true")
    endif()
  endif()

  set(ep_args
    PREFIX "${CPPDEPS_ROOT}/isolated/prefix/${name}"
    SOURCE_DIR "${src}"
    BINARY_DIR "${binary_dir}"
    INSTALL_DIR "${install_dir}"
    DOWNLOAD_COMMAND ""
    UPDATE_COMMAND ""
    PATCH_COMMAND ""
    CMAKE_ARGS ${cmake_args}
    BUILD_ALWAYS FALSE
  )
  foreach(phase CONFIGURE BUILD INSTALL)
    if(custom_${phase}_COMMAND)
      list(APPEND ep_args "${phase}_COMMAND" ${custom_${phase}_COMMAND})
    endif()
  endforeach()
  set(ep_target "cppdeps_ep_${norm}")
  if(TARGET "${ep_target}")
    _cppdeps_fatal("${name}: isolated ExternalProject target already exists: ${ep_target}")
  endif()
  # Ninja requires an explicit producer rule for imported artifacts.
  # The ExternalProject build step owns the complete configure/build/install
  # chain, so declare the installed artifact as a byproduct of that chain.
  if(provides AND custom_ARTIFACT)
    set(byproduct "${custom_ARTIFACT}")
    string(REPLACE "<SOURCE_DIR>" "${src}" byproduct "${byproduct}")
    string(REPLACE "<BINARY_DIR>" "${binary_dir}" byproduct "${byproduct}")
    string(REPLACE "<INSTALL_DIR>" "${install_dir}" byproduct "${byproduct}")
    if(NOT IS_ABSOLUTE "${byproduct}")
      set(byproduct "${install_dir}/${byproduct}")
    endif()
    list(APPEND ep_args BUILD_BYPRODUCTS "${byproduct}")
  endif()
  ExternalProject_Add("${ep_target}" ${ep_args})

  if(provides)
    list(LENGTH provides n_provides)
    if(NOT n_provides EQUAL 1)
      _cppdeps_fatal("${name}: isolated mode currently supports one PROVIDES target")
    endif()
    if(NOT custom_ARTIFACT)
      _cppdeps_fatal("${name}: isolated PROVIDES requires ARTIFACT (path relative to install directory or absolute path)")
    endif()
    list(GET provides 0 public_target)
    if(TARGET "${public_target}")
      _cppdeps_fatal("${name}: target '${public_target}' already exists")
    endif()
    set(artifact "${custom_ARTIFACT}")
    string(REPLACE "<SOURCE_DIR>" "${src}" artifact "${artifact}")
    string(REPLACE "<BINARY_DIR>" "${binary_dir}" artifact "${artifact}")
    string(REPLACE "<INSTALL_DIR>" "${install_dir}" artifact "${artifact}")
    if(NOT IS_ABSOLUTE "${artifact}")
      set(artifact "${install_dir}/${artifact}")
    endif()
    get_filename_component(artifact_parent "${artifact}" DIRECTORY)
    file(MAKE_DIRECTORY "${artifact_parent}")
    # TARGET name with :: is valid for an imported library.
    add_library("${public_target}" UNKNOWN IMPORTED GLOBAL)
    set_target_properties("${public_target}" PROPERTIES IMPORTED_LOCATION "${artifact}")
    add_dependencies("${public_target}" "${ep_target}")
    foreach(dir IN LISTS custom_INCLUDE_DIRS)
      string(REPLACE "<SOURCE_DIR>" "${src}" dir "${dir}")
      string(REPLACE "<BINARY_DIR>" "${binary_dir}" dir "${dir}")
      string(REPLACE "<INSTALL_DIR>" "${install_dir}" dir "${dir}")
      if(NOT IS_ABSOLUTE "${dir}")
        set(dir "${install_dir}/${dir}")
      endif()
      file(MAKE_DIRECTORY "${dir}")
      set_property(TARGET "${public_target}" APPEND PROPERTY INTERFACE_INCLUDE_DIRECTORIES "${dir}")
    endforeach()
  endif()
endfunction()

function(_cppdeps_make_available_one name)
  _cppdeps_norm_name(norm "${name}")
  get_property(src GLOBAL PROPERTY "CPPDEPS_${norm}_SOURCE_DIR")
  get_property(build GLOBAL PROPERTY "CPPDEPS_${norm}_BUILD")
  get_property(provides GLOBAL PROPERTY "CPPDEPS_${norm}_PROVIDES")
  if(NOT src)
    _cppdeps_fatal("${name}: not checked out. Call cppdeps_checkout_all() first.")
  endif()

  if(build STREQUAL "NONE")
    return()
  elseif(build STREQUAL "HEADER_ONLY")
    if(NOT provides)
      _cppdeps_fatal("${name}: HEADER_ONLY build requires PROVIDES <target>")
    endif()
    list(GET provides 0 target)
    add_library("cppdeps_${name}" INTERFACE)
    target_include_directories("cppdeps_${name}" INTERFACE "${src}/include")
    if(NOT TARGET "${target}")
      add_library("${target}" ALIAS "cppdeps_${name}")
    endif()
  elseif(build STREQUAL "ISOLATED")
    _cppdeps_make_isolated("${name}" "${src}" "${provides}")
  elseif(build STREQUAL "CMAKE_ADD_SUBDIRECTORY")
    _cppdeps_apply_cmake_options("${name}")
    add_subdirectory("${src}" "${CPPDEPS_ROOT}/build/${name}" EXCLUDE_FROM_ALL)
    foreach(target IN LISTS provides)
      if(NOT TARGET "${target}")
        _cppdeps_fatal("${name}: expected provided target '${target}' was not created")
      endif()
    endforeach()
  else()
    _cppdeps_fatal("${name}: unsupported BUILD mode '${build}'")
  endif()
endfunction()

function(cppdeps_make_available_all)
  get_property(deps GLOBAL PROPERTY CPPDEPS_DEPS)
  foreach(name IN LISTS deps)
    _cppdeps_make_available_one("${name}")
  endforeach()
endfunction()

function(cppdeps_install_all)
  set(options WRITE_LOCKFILE)
  cmake_parse_arguments(ARG "${options}" "" "" ${ARGN})
  cppdeps_resolve_all(${ARGN})
  cppdeps_checkout_all()
  cppdeps_make_available_all()
endfunction()
