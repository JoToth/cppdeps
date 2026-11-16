# Fail-fast contract validation for arbitrary configuration-specific artifacts.
cmake_minimum_required(VERSION 3.20)
set(root "${CMAKE_CURRENT_LIST_DIR}/..")
set(work "${CMAKE_CURRENT_BINARY_DIR}/tmp/isolated_config_artifacts_contract")
file(REMOVE_RECURSE "${work}")
file(MAKE_DIRECTORY "${work}/source")
file(WRITE "${work}/source/README" "non-CMake fixture\n")
file(TO_CMAKE_PATH "${root}/cmake/CppDeps.cmake" module)
file(TO_CMAKE_PATH "${work}/source" local_src)
function(check_case label declaration configs expected)
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
  execute_process(COMMAND "${CMAKE_COMMAND}" -G Ninja
    "-DCMAKE_BUILD_TYPE:STRING=${configs}"
    -S "${consumer}" -B "${consumer}/build"
    RESULT_VARIABLE rc OUTPUT_VARIABLE out ERROR_VARIABLE err)
  if(rc EQUAL 0 OR NOT "${out}\n${err}" MATCHES "${expected}")
    message(FATAL_ERROR "${label}: expected '${expected}', rc=${rc}:\n${out}\n${err}")
  endif()
endfunction()
set(ok "CONFIG_ARTIFACTS ASan:alpha::alpha=lib/alpha.a ASan:beta::beta=lib/beta.a")
check_case(missing "CONFIG_ARTIFACTS ASan:alpha::alpha=lib/alpha.a" ASan "missing CONFIG_ARTIFACTS mapping")
check_case(unknown "CONFIG_ARTIFACTS ASan:alpha::alpha=lib/alpha.a ASan:wrong::wrong=lib/wrong.a" ASan "unknown target")
check_case(duplicate "CONFIG_ARTIFACTS ASan:alpha::alpha=lib/a.a ASan:alpha::alpha=lib/a2.a ASan:beta::beta=lib/b.a" ASan "duplicate CONFIG_ARTIFACTS mapping")
check_case(wrong_config "CONFIG_ARTIFACTS Coverage:alpha::alpha=lib/a.a Coverage:beta::beta=lib/b.a" ASan "unconfigured configuration")
check_case(mixed "ARTIFACTS alpha::alpha=lib/a.a beta::beta=lib/b.a ${ok}" ASan "cannot be combined")
check_case(noconfig "${ok}" "" "requires CMAKE_BUILD_TYPE")
check_case(shared "CONFIG_ARTIFACTS ASan:alpha::alpha=lib/shared.a ASan:beta::beta=lib/shared.a" ASan "may not share")
file(REMOVE_RECURSE "${work}")
message(STATUS "configuration-specific artifact contract validation passed")
