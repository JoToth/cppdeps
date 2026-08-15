cmake_minimum_required(VERSION 3.20)

get_filename_component(_root "${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)

set(CPPDEPS_BOOTSTRAP_SOURCE_DIR "${_root}" CACHE PATH "" FORCE)
include("${_root}/bootstrap/cppdeps-bootstrap.cmake")

if(NOT COMMAND cppdeps_add)
  message(FATAL_ERROR "standalone bootstrapper did not load cppdeps_add")
endif()


message(STATUS "remote bootstrap test passed")
