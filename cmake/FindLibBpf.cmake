# - Try to find libbpf
# Once done this will define
#
#  LIBBPF_FOUND - system has libbpf
#  LIBBPF_INCLUDE_DIRS - the libbpf include directory
#  LIBBPF_LIBRARIES - Link these to use libbpf
#  LIBBPF_DEFINITIONS - Compiler switches required for using libbpf

#if (LIBBPF_LIBRARIES AND LIBBPF_INCLUDE_DIRS)
#  set (LibBpf_FIND_QUIETLY TRUE)
#endif (LIBBPF_LIBRARIES AND LIBBPF_INCLUDE_DIRS)

if (USE_SYSTEM_BPF_BCC)
  find_path (LIBBPF_INCLUDE_DIRS
    NAMES
      bpf/bpf.h
      bpf/btf.h
      bpf/libbpf.h
    PATHS
      ENV CPATH)

  find_library (LIBBPF_LIBRARIES
    NAMES
      bpf
    PATHS
      ENV LIBRARY_PATH
      ENV LD_LIBRARY_PATH)
  set(LIBBPF_ERROR_MESSAGE "Please install the libbpf development package")
else()
  # Use static linking with vendored libbpf
  set(SAVED_CMAKE_FIND_LIBRARY_SUFFIXES ${CMAKE_FIND_LIBRARY_SUFFIXES})
  set(CMAKE_FIND_LIBRARY_SUFFIXES ".a")
  set(SAVED_CMAKE_PREFIX_PATH ${CMAKE_PREFIX_PATH})
  set(CMAKE_PREFIX_PATH ${BPF_BCC_PREFIX_PATH})
  find_path (LIBBPF_INCLUDE_DIRS
    NAMES
      bpf/bpf.h
      bpf/btf.h
      bpf/libbpf.h
    NO_CMAKE_SYSTEM_PATH)

  find_library (LIBBPF_LIBRARIES
    NAMES
      bpf
    NO_CMAKE_SYSTEM_PATH)
  set(CMAKE_PREFIX_PATH ${SAVED_CMAKE_PREFIX_PATH})
  set(LIBBPF_ERROR_MESSAGE "Please run ${CMAKE_SOURCE_DIR}/build-libs.sh from the build folder first")
  set(CMAKE_FIND_LIBRARY_SUFFIXES ${SAVED_CMAKE_FIND_LIBRARY_SUFFIXES})
endif()

include (FindPackageHandleStandardArgs)

# handle the QUIETLY and REQUIRED arguments and set LIBBPF_FOUND to TRUE if all listed variables are TRUE
FIND_PACKAGE_HANDLE_STANDARD_ARGS(LibBpf ${LIBBPF_ERROR_MESSAGE}
  LIBBPF_LIBRARIES
  LIBBPF_INCLUDE_DIRS)

mark_as_advanced(LIBBPF_INCLUDE_DIRS LIBBPF_LIBRARIES)

# We need btf_dump support, set LIBBPF_BTF_DUMP_FOUND
# when it's found.
if (KERNEL_INCLUDE_DIRS)
  set(INCLUDE_KERNEL -isystem ${KERNEL_INCLUDE_DIRS})
endif ()
include(CheckSymbolExists)
# adding also elf for static build check
SET(CMAKE_REQUIRED_LIBRARIES ${LIBBPF_LIBRARIES} elf z)
# libbpf quirk, needs upstream fix
SET(CMAKE_REQUIRED_DEFINITIONS -include stdbool.h -isystem "${LIBBPF_INCLUDE_DIRS}" ${INCLUDE_KERNEL})
check_symbol_exists(btf_dump__new "${LIBBPF_INCLUDE_DIRS}/bpf/btf.h" HAVE_BTF_DUMP)
if (HAVE_BTF_DUMP)
  set(LIBBPF_BTF_DUMP_FOUND TRUE)
endif ()
check_symbol_exists(btf_dump__emit_type_decl "${LIBBPF_INCLUDE_DIRS}/bpf/btf.h" HAVE_LIBBPF_BTF_DUMP_EMIT_TYPE_DECL)

check_symbol_exists(bpf_prog_load "${LIBBPF_INCLUDE_DIRS}/bpf/bpf.h" HAVE_LIBBPF_BPF_PROG_LOAD)
check_symbol_exists(bpf_map_create "${LIBBPF_INCLUDE_DIRS}/bpf/bpf.h" HAVE_LIBBPF_BPF_MAP_CREATE)
check_symbol_exists(bpf_map_lookup_batch "${LIBBPF_INCLUDE_DIRS}/bpf/bpf.h" HAVE_LIBBPF_MAP_BATCH)
check_symbol_exists(bpf_link_create "${LIBBPF_INCLUDE_DIRS}/bpf/bpf.h" HAVE_LIBBPF_LINK_CREATE)
check_symbol_exists(bpf_prog_test_run_opts "${LIBBPF_INCLUDE_DIRS}/bpf/bpf.h" HAVE_LIBBPF_PROG_TEST_RUN_OPTS)
SET(CMAKE_REQUIRED_DEFINITIONS)
SET(CMAKE_REQUIRED_LIBRARIES)

INCLUDE(CheckCXXSourceCompiles)
SET(CMAKE_REQUIRED_INCLUDES ${LIBBPF_INCLUDE_DIRS})
SET(CMAKE_REQUIRED_LIBRARIES ${LIBBPF_LIBRARIES} elf z)
CHECK_CXX_SOURCE_COMPILES("
#include <bpf/btf.h>

int main(void) {
  btf__type_cnt(NULL);
  return 0;
}
" HAVE_LIBBPF_BTF_TYPE_CNT)

CHECK_CXX_SOURCE_COMPILES("
#include <bpf/btf.h>

int main(void) {
  const struct btf_dump_opts *opts = (const struct btf_dump_opts*) 1;

  btf_dump__new(NULL, NULL, NULL, opts);
  return 0;
}
" HAVE_LIBBPF_BTF_DUMP_NEW_V0_6_0)

CHECK_CXX_SOURCE_COMPILES("
#include <bpf/btf.h>

int main(void) {
  btf_dump__new_deprecated(NULL, NULL, NULL, NULL);
  return 0;
}
" HAVE_LIBBPF_BTF_DUMP_NEW_DEPRECATED)

CHECK_CXX_SOURCE_COMPILES("
#include <bpf/bpf.h>

int main(void) {
  DECLARE_LIBBPF_OPTS(bpf_link_create_opts, opts);

  opts.kprobe_multi.syms = NULL;
  return 0;
}
" HAVE_LIBBPF_KPROBE_MULTI)
SET(CMAKE_REQUIRED_INCLUDES)
SET(CMAKE_REQUIRED_LIBRARIES)
