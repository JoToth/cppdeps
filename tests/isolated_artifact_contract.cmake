# Validate imported target contract and fail-fast errors without a compiler.
cmake_minimum_required(VERSION 3.20)
set(root "${CMAKE_CURRENT_LIST_DIR}/..")
set(work "${CMAKE_CURRENT_BINARY_DIR}/tmp/isolated_artifact_contract")
file(REMOVE_RECURSE "${work}")
file(MAKE_DIRECTORY "${work}/source" "${work}/consumer")
file(WRITE "${work}/source/README.txt" "Non-CMake test source\n")
file(TO_CMAKE_PATH "${root}/cmake/CppDeps.cmake" module)
file(TO_CMAKE_PATH "${work}/source" local_src)

function(check_contract label extra should_succeed expected_error)
  set(consumer "${work}/consumer/${label}")
  file(MAKE_DIRECTORY "${consumer}")
  set(prelude "")
  if(label STREQUAL "existing_target")
    set(prelude "add_library(example::example INTERFACE IMPORTED)")
  endif()
  set(config [=[
cmake_minimum_required(VERSION 3.20)
project(contract LANGUAGES NONE)
set(DEP_EXAMPLE_SOURCE_DIR "@local_src@")
include("@module@")
@prelude@
cppdeps_add(
  NAME example
  GIT_REPOSITORY https://invalid.invalid/example.git
  TAG v1
  BUILD_COMMAND "${CMAKE_COMMAND}" -E true
  @extra@
)
cppdeps_install_all()
if(@should_succeed@)
  if(NOT TARGET example::example)
    message(FATAL_ERROR "expected imported target was not created")
  endif()
  get_target_property(location example::example IMPORTED_LOCATION)
  get_target_property(include_dirs example::example INTERFACE_INCLUDE_DIRECTORIES)
  get_target_property(is_imported example::example IMPORTED)
  if(NOT is_imported)
    message(FATAL_ERROR "provided target is not imported")
  endif()
  set(expected_artifact "${CPPDEPS_ROOT}/isolated/install/example/lib/example.a")
  if(NOT location STREQUAL expected_artifact)
    message(FATAL_ERROR "wrong imported artifact: '${location}' expected '${expected_artifact}'")
  endif()
  set(expected_include "${CPPDEPS_ROOT}/isolated/install/example/include")
  if(NOT include_dirs STREQUAL expected_include)
    message(FATAL_ERROR "wrong include directories: '${include_dirs}'")
  endif()
endif()
]=])
  string(CONFIGURE "${config}" config @ONLY)
  file(WRITE "${consumer}/CMakeLists.txt" "${config}")
  execute_process(COMMAND "${CMAKE_COMMAND}" -S "${consumer}" -B "${consumer}/build"
    RESULT_VARIABLE rc OUTPUT_VARIABLE out ERROR_VARIABLE err)
  if(should_succeed)
    if(NOT rc EQUAL 0)
      message(FATAL_ERROR "${label}: expected success, got:\n${out}\n${err}")
    endif()
  else()
    if(rc EQUAL 0)
      message(FATAL_ERROR "${label}: unexpectedly succeeded")
    endif()
    if(NOT "${out}\n${err}" MATCHES "${expected_error}")
      message(FATAL_ERROR "${label}: wrong failure:\n${out}\n${err}")
    endif()
  endif()
endfunction()

check_contract(valid
  "PROVIDES example::example\n  ARTIFACT lib/example.a\n  INCLUDE_DIRS include include"
  TRUE "")
check_contract(missing_artifact "PROVIDES example::example" FALSE "requires ARTIFACT")
check_contract(orphan_artifact "ARTIFACT lib/example.a" FALSE "require PROVIDES")
check_contract(orphan_includes "INCLUDE_DIRS include" FALSE "require PROVIDES")
check_contract(multiple_provides
  "PROVIDES example::example example::other\n  ARTIFACT lib/example.a"
  FALSE "exactly one PROVIDES")
check_contract(existing_target
  "PROVIDES example::example\n  ARTIFACT lib/example.a"
  FALSE "already exists")
check_contract(unknown_placeholder
  "PROVIDES example::example\n  ARTIFACT <UNKNOWN_DIR>/example.a"
  FALSE "unsupported placeholder")
file(REMOVE_RECURSE "${work}")
message(STATUS "isolated artifact contract test passed")
