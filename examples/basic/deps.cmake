cppdeps_add(
  NAME fmt
  PROVIDES fmt::fmt
  GIT_REPOSITORY https://github.com/fmtlib/fmt.git
  TAG 11.1.4
  BUILD CMAKE_ADD_SUBDIRECTORY
  CMAKE_OPTIONS
    FMT_TEST=OFF
    FMT_DOC=OFF
)
