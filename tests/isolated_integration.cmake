# Standalone integration: separate configure/build/install and a linkable target.
cmake_minimum_required(VERSION 3.20)
set(root "${CMAKE_CURRENT_LIST_DIR}/..")
set(work "${CMAKE_CURRENT_BINARY_DIR}/tmp/isolated_integration")
file(REMOVE_RECURSE "${work}")
file(MAKE_DIRECTORY "${work}/lib/include" "${work}/consumer")
file(WRITE "${work}/lib/CMakeLists.txt" [=[
cmake_minimum_required(VERSION 3.20)
project(example LANGUAGES CXX)
add_library(example STATIC example.cpp)
target_include_directories(example PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/include")
install(TARGETS example ARCHIVE DESTINATION lib)
install(DIRECTORY include/ DESTINATION include)
]=])
file(WRITE "${work}/lib/example.cpp" "int example_answer() { return 42; }\n")
file(WRITE "${work}/lib/include/example.h" "int example_answer();\n")
file(WRITE "${work}/consumer/main.cpp" "#include <example.h>\nint main() { return example_answer() == 42 ? 0 : 1; }\n")
# This test runs from cmake -P (the parent project uses LANGUAGES NONE),
# so no compiler is inherited from a configured parent language.
# Prefer a compiler explicitly provided by the CI environment. On MSYS2, it
# must be a Windows-compatible absolute path (e.g. C:/msys64/ucrt64/bin/g++.exe).
if(DEFINED ENV{CXX} AND NOT "$ENV{CXX}" STREQUAL "")
  set(_test_cxx "$ENV{CXX}")
else()
  find_program(_test_cxx NAMES g++ clang++ c++)
endif()
if(NOT _test_cxx OR NOT EXISTS "${_test_cxx}")
  message(FATAL_ERROR
    "isolated integration requires a C++ compiler. "
    "CXX='$ENV{CXX}', MSYSTEM='$ENV{MSYSTEM}', PATH='$ENV{PATH}'")
endif()
execute_process(COMMAND "${_test_cxx}" --version
  RESULT_VARIABLE _cxx_rc OUTPUT_VARIABLE _cxx_out ERROR_VARIABLE _cxx_err)
if(NOT _cxx_rc EQUAL 0)
  message(FATAL_ERROR "C++ compiler is not runnable: '${_test_cxx}'\n${_cxx_err}")
endif()
message(STATUS "isolated integration compiler: ${_test_cxx}")
# Native CMake on Windows needs a native absolute path, not an MSYS /ucrt64 path.
file(TO_CMAKE_PATH "${_test_cxx}" _test_cxx_cmake)
file(TO_CMAKE_PATH "${root}/cmake/CppDeps.cmake" module)
file(TO_CMAKE_PATH "${work}/lib" local_src)
set(_consumer_cmake [=[
cmake_minimum_required(VERSION 3.20)
project(consumer LANGUAGES CXX)
set(DEP_EXAMPLE_SOURCE_DIR "@local_src@")
include("@module@")
cppdeps_add(
  NAME example
  GIT_REPOSITORY https://invalid.invalid/example.git
  TAG v1
  ISOLATED
  CMAKE_OPTIONS "CMAKE_CXX_COMPILER=@_test_cxx_cmake@"
  PROVIDES example::example
  ARTIFACT "lib/${CMAKE_STATIC_LIBRARY_PREFIX}example${CMAKE_STATIC_LIBRARY_SUFFIX}"
  INCLUDE_DIRS include
)
cppdeps_install_all()
add_executable(consumer main.cpp)
target_link_libraries(consumer PRIVATE example::example)
]=])
string(CONFIGURE "${_consumer_cmake}" _consumer_cmake @ONLY)
file(WRITE "${work}/consumer/CMakeLists.txt" "${_consumer_cmake}")
# Default generator of the parent build is passed explicitly by CTest.
set(gen_args)
if(DEFINED CPPDEPS_TEST_GENERATOR AND NOT CPPDEPS_TEST_GENERATOR STREQUAL "")
  list(APPEND gen_args -G "${CPPDEPS_TEST_GENERATOR}")
endif()
execute_process(COMMAND "${CMAKE_COMMAND}" ${gen_args}
  "-DCMAKE_CXX_COMPILER:FILEPATH=${_test_cxx_cmake}"
  -S "${work}/consumer" -B "${work}/build"
  RESULT_VARIABLE rc OUTPUT_VARIABLE out ERROR_VARIABLE err)
if(NOT rc EQUAL 0)
  message(FATAL_ERROR "isolated configure failed:\n${out}\n${err}")
endif()
execute_process(COMMAND "${CMAKE_COMMAND}" --build "${work}/build" --parallel 2
  RESULT_VARIABLE rc OUTPUT_VARIABLE out ERROR_VARIABLE err)
if(NOT rc EQUAL 0)
  message(FATAL_ERROR "isolated build failed:\n${out}\n${err}")
endif()
execute_process(COMMAND "${work}/build/consumer" RESULT_VARIABLE rc)
if(NOT rc EQUAL 0)
  message(FATAL_ERROR "isolated consumer execution failed (${rc})")
endif()
file(REMOVE_RECURSE "${work}")
message(STATUS "isolated integration test passed")
