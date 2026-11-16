# Validate per-target artifact mapping failures without requiring a compiler.
cmake_minimum_required(VERSION 3.20)
set(root "${CMAKE_CURRENT_LIST_DIR}/..")
set(work "${CMAKE_CURRENT_BINARY_DIR}/tmp/isolated_multi_artifact_contract")
file(REMOVE_RECURSE "${work}")
file(MAKE_DIRECTORY "${work}/source")
file(WRITE "${work}/source/README.txt" "non-CMake fixture\n")
file(TO_CMAKE_PATH "${root}/cmake/CppDeps.cmake" module)
file(TO_CMAKE_PATH "${work}/source" local_src)

function(check_contract label declaration expected_error)
  set(consumer "${work}/${label}")
  file(MAKE_DIRECTORY "${consumer}")
  set(config [=[
cmake_minimum_required(VERSION 3.20)
project(contract LANGUAGES NONE)
set(DEP_EXAMPLE_SOURCE_DIR "@local_src@")
include("@module@")
cppdeps_add(NAME example GIT_REPOSITORY https://invalid.invalid/example.git TAG v1
  BUILD_COMMAND "${CMAKE_COMMAND}" -E true
  PROVIDES alpha::alpha beta::beta
  @declaration@)
cppdeps_install_all()
]=])
  string(CONFIGURE "${config}" config @ONLY)
  file(WRITE "${consumer}/CMakeLists.txt" "${config}")
  set(gen_args)
  if(DEFINED CPPDEPS_TEST_GENERATOR AND NOT CPPDEPS_TEST_GENERATOR STREQUAL "")
    list(APPEND gen_args -G "${CPPDEPS_TEST_GENERATOR}")
  endif()
  execute_process(COMMAND "${CMAKE_COMMAND}" ${gen_args}
    -S "${consumer}" -B "${consumer}/build"
    RESULT_VARIABLE rc OUTPUT_VARIABLE out ERROR_VARIABLE err)
  if(rc EQUAL 0 OR NOT "${out}\n${err}" MATCHES "${expected_error}")
    message(FATAL_ERROR "${label}: expected '${expected_error}', exit=${rc}:\n${out}\n${err}")
  endif()
endfunction()

check_contract(old_api "ARTIFACT lib/alpha.a" "exactly one PROVIDES")
check_contract(missing "ARTIFACTS alpha::alpha=lib/alpha.a" "missing ARTIFACTS mapping")
check_contract(unknown "ARTIFACTS alpha::alpha=lib/alpha.a gamma::gamma=lib/gamma.a" "unknown target")
check_contract(duplicate "ARTIFACTS alpha::alpha=lib/alpha.a alpha::alpha=lib/again.a beta::beta=lib/beta.a" "duplicate ARTIFACTS mapping")
check_contract(reused "ARTIFACTS alpha::alpha=lib/shared.a beta::beta=lib/shared.a" "may not share")
check_contract(malformed "ARTIFACTS alpha::alpha beta::beta=lib/beta.a" "must use target=path")
check_contract(mixed "ARTIFACT lib/a.a ARTIFACTS alpha::alpha=lib/a.a beta::beta=lib/b.a" "mutually exclusive")
file(REMOVE_RECURSE "${work}")
message(STATUS "isolated multi-artifact contract tests passed")
