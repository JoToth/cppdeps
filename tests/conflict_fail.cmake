# SPDX-License-Identifier: BSD-3-Clause
#
# Copyright (c) 2026, Jozsef Toth
#
# This file is part of cppdeps.
# See LICENSE file for full license text.

include("${CMAKE_CURRENT_LIST_DIR}/../cmake/CppDeps.cmake")
cppdeps_add(NAME same GIT_REPOSITORY "https://example.invalid/same.git" COMMIT 111 BUILD NONE)
cppdeps_add(NAME same GIT_REPOSITORY "https://example.invalid/same.git" COMMIT 222 BUILD NONE)
