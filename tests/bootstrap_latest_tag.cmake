cmake_minimum_required(VERSION 3.20)

get_filename_component(_root "${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)

set(CPPDEPS_BOOTSTRAP_SOURCE_DIR "${_root}" CACHE PATH "" FORCE)
include("${_root}/bootstrap/cppdeps-bootstrap.cmake")

set(_ls_remote_output "
1111111111111111111111111111111111111111\trefs/tags/v1.0.4
2222222222222222222222222222222222222222\trefs/tags/v1.0.10
3333333333333333333333333333333333333333\trefs/tags/v1.0.2
4444444444444444444444444444444444444444\trefs/tags/not-a-release
5555555555555555555555555555555555555555\trefs/tags/v2.0.0-rc1
")

_cppdeps_bootstrap_tags_from_ls_remote("${_ls_remote_output}" _tags)
_cppdeps_bootstrap_select_latest_tag("${_tags}" _latest)

if(NOT _latest STREQUAL "v1.0.10")
  message(FATAL_ERROR "Expected latest stable tag v1.0.10, got '${_latest}' from '${_tags}'")
endif()

set(CPPDEPS_BOOTSTRAP_GIT_TAG_REGEX "^v[0-9]+\\.[0-9]+\\.[0-9]+$" CACHE STRING "" FORCE)
_cppdeps_bootstrap_tags_from_ls_remote("${_ls_remote_output}" _stable_tags)
_cppdeps_bootstrap_select_latest_tag("${_stable_tags}" _stable_latest)

if(NOT _stable_latest STREQUAL "v1.0.10")
  message(FATAL_ERROR "Expected latest stable tag v1.0.10, got '${_stable_latest}' from '${_stable_tags}'")
endif()

message(STATUS "bootstrap latest-tag test passed")
