cmake_minimum_required(VERSION 3.20)
project(CppDeps VERSION 1.0.4 LANGUAGES NONE)

include(CTest)

if(BUILD_TESTING)
  add_test(NAME cppdeps_syntax
    COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_LIST_DIR}/tests/syntax.cmake
  )
  add_test(NAME cppdeps_git_integration
    COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_LIST_DIR}/tests/git_integration.cmake
  )
  add_test(NAME cppdeps_lockfile_roundtrip
    COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_LIST_DIR}/tests/lockfile_roundtrip.cmake
  )
  add_test(NAME cppdeps_cli_override
    COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_LIST_DIR}/tests/cli_override.cmake
  )
  add_test(NAME cppdeps_conflict_fail
    COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_LIST_DIR}/tests/conflict_fail.cmake
  )
  add_test(NAME cppdeps_path_normalization
    COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_LIST_DIR}/tests/path_normalization.cmake
  )
  set_tests_properties(cppdeps_conflict_fail PROPERTIES WILL_FAIL TRUE)
endif()
