# End-to-end: two imported libraries from one independently built project.
cmake_minimum_required(VERSION 3.20)
set(root "${CMAKE_CURRENT_LIST_DIR}/..")
set(work "${CMAKE_CURRENT_BINARY_DIR}/tmp/isolated_multi_artifact")
file(REMOVE_RECURSE "${work}")
file(MAKE_DIRECTORY "${work}/lib/include" "${work}/consumer")
file(WRITE "${work}/lib/CMakeLists.txt" [=[
cmake_minimum_required(VERSION 3.20)
project(two_libs LANGUAGES CXX)
add_library(alpha STATIC alpha.cpp)
add_library(beta STATIC beta.cpp)
target_include_directories(alpha PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_include_directories(beta PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/include")
install(TARGETS alpha beta ARCHIVE DESTINATION lib)
install(DIRECTORY include/ DESTINATION include)
]=])
file(WRITE "${work}/lib/alpha.cpp" "int alpha() { return 19; }\n")
file(WRITE "${work}/lib/beta.cpp" "int beta() { return 23; }\n")
file(WRITE "${work}/lib/include/alpha.h" "int alpha();\n")
file(WRITE "${work}/lib/include/beta.h" "int beta();\n")
file(WRITE "${work}/consumer/main.cpp" "#include <alpha.h>\n#include <beta.h>\nint main(){return alpha()+beta()==42 ? 0 : 1;}\n")

if(DEFINED ENV{CXX} AND NOT "$ENV{CXX}" STREQUAL "")
  set(test_cxx "$ENV{CXX}")
else()
  find_program(test_cxx NAMES g++ clang++ c++ HINTS "$ENV{MINGW_PREFIX}/bin")
endif()
if(NOT test_cxx OR NOT EXISTS "${test_cxx}")
  message(FATAL_ERROR "isolated multi-artifact test requires CXX (CXX='$ENV{CXX}')")
endif()
file(TO_CMAKE_PATH "${test_cxx}" test_cxx)
file(TO_CMAKE_PATH "${root}/cmake/CppDeps.cmake" module)
file(TO_CMAKE_PATH "${work}/lib" local_src)
set(config [=[
cmake_minimum_required(VERSION 3.20)
project(two_consumer LANGUAGES CXX)
set(DEP_EXAMPLE_SOURCE_DIR "@local_src@")
include("@module@")
cppdeps_add(NAME example
  GIT_REPOSITORY https://invalid.invalid/example.git TAG v1
  ISOLATED CMAKE_OPTIONS "CMAKE_CXX_COMPILER=@test_cxx@"
  PROVIDES alpha::alpha beta::beta
  ARTIFACTS
    "beta::beta=lib/${CMAKE_STATIC_LIBRARY_PREFIX}beta${CMAKE_STATIC_LIBRARY_SUFFIX}"
    "alpha::alpha=lib/${CMAKE_STATIC_LIBRARY_PREFIX}alpha${CMAKE_STATIC_LIBRARY_SUFFIX}"
  INCLUDE_DIRS include)
cppdeps_install_all()
add_executable(consumer main.cpp)
target_link_libraries(consumer PRIVATE alpha::alpha beta::beta)
]=])
string(CONFIGURE "${config}" config @ONLY)
file(WRITE "${work}/consumer/CMakeLists.txt" "${config}")
set(gen_args)
if(DEFINED CPPDEPS_TEST_GENERATOR AND NOT CPPDEPS_TEST_GENERATOR STREQUAL "")
  list(APPEND gen_args -G "${CPPDEPS_TEST_GENERATOR}")
endif()
execute_process(COMMAND "${CMAKE_COMMAND}" ${gen_args}
  "-DCMAKE_CXX_COMPILER:FILEPATH=${test_cxx}"
  -S "${work}/consumer" -B "${work}/build"
  RESULT_VARIABLE rc OUTPUT_VARIABLE out ERROR_VARIABLE err)
if(NOT rc EQUAL 0)
  message(FATAL_ERROR "multi-artifact configure failed:\n${out}\n${err}")
endif()
execute_process(COMMAND "${CMAKE_COMMAND}" --build "${work}/build" --parallel 2
  RESULT_VARIABLE rc OUTPUT_VARIABLE out ERROR_VARIABLE err)
if(NOT rc EQUAL 0)
  message(FATAL_ERROR "multi-artifact build failed:\n${out}\n${err}")
endif()
execute_process(COMMAND "${work}/build/consumer" RESULT_VARIABLE rc)
if(NOT rc EQUAL 0)
  message(FATAL_ERROR "multi-artifact consumer exited with ${rc}")
endif()
file(REMOVE_RECURSE "${work}")
message(STATUS "isolated multi-artifact integration passed")
