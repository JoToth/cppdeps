# SPDX-License-Identifier: BSD-3-Clause
#
# Copyright (c) 2026, Jozsef Toth
#
# This file is part of cppdeps.
# See LICENSE file for full license text.

include("${CMAKE_CURRENT_LIST_DIR}/../cmake/CppDeps.cmake")

_cppdeps_repo_equal(eq_remote "https://github.com/fmtlib/fmt.git/" "https://github.com/fmtlib/fmt.git")
if(NOT eq_remote)
  message(FATAL_ERROR "remote URL normalization failed")
endif()

set(local_a "${CMAKE_CURRENT_BINARY_DIR}/tmp/path_norm_repo")
file(MAKE_DIRECTORY "${local_a}")
_cppdeps_normalize_path(local_a_norm "${local_a}")

if(WIN32)
  string(SUBSTRING "${local_a_norm}" 0 1 drive)
  string(SUBSTRING "${local_a_norm}" 2 -1 rest)
  string(TOLOWER "${drive}" drive_lower)
  set(msys_like "/${drive_lower}${rest}")
  _cppdeps_paths_equal(eq_path "${local_a_norm}" "${msys_like}")
  if(NOT eq_path)
    message(FATAL_ERROR "MSYS path normalization failed: '${local_a_norm}' vs '${msys_like}'")
  endif()
endif()
