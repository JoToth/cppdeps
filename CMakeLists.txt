cmake_minimum_required(VERSION 3.20)
project(CppDeps VERSION 1.0.4 LANGUAGES NONE)

if(PROJECT_IS_TOP_LEVEL
   AND CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
  include(CTest)
endif()

if(PROJECT_IS_TOP_LEVEL
   AND CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR
   AND BUILD_TESTING)
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
  add_test(NAME cppdeps_remote_bootstrap
    COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_LIST_DIR}/tests/remote_bootstrap.cmake
  )
  add_test(NAME cppdeps_bootstrap_latest_tag
    COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_LIST_DIR}/tests/bootstrap_latest_tag.cmake
  )
  add_test(NAME cppdeps_bootstrap_fetch_integration
    COMMAND "${CMAKE_COMMAND}"
      "-DCPPDEPS_TEST_GENERATOR=${CMAKE_GENERATOR}"
      -P "${CMAKE_CURRENT_LIST_DIR}/tests/bootstrap_fetch_integration.cmake"
  )
  add_test(NAME cppdeps_local_override_offline
    COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_LIST_DIR}/tests/local_override_offline.cmake
  )
  add_test(NAME cppdeps_dirty_checkout
    COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_LIST_DIR}/tests/dirty_checkout.cmake
  )
  set_tests_properties(cppdeps_conflict_fail PROPERTIES WILL_FAIL TRUE)
endif()
