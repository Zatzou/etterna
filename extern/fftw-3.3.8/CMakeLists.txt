cmake_minimum_required (VERSION 3.5)

if (NOT DEFINED CMAKE_BUILD_TYPE)
  set (CMAKE_BUILD_TYPE Release CACHE STRING "Build type")
endif ()

project (fftw)

if (POLICY CMP0042)
  cmake_policy (SET CMP0042 NEW)
endif ()

option (BUILD_SHARED_LIBS "Build shared libraries" OFF)

option (ENABLE_OPENMP "Use OpenMP for multithreading" OFF)
option (ENABLE_THREADS "Use pthread for multithreading" OFF)
option (WITH_COMBINED_THREADS "Merge thread library" OFF)

option (ENABLE_FLOAT "single-precision" ON)
option (ENABLE_LONG_DOUBLE "long-double precision" OFF)
option (ENABLE_QUAD_PRECISION "quadruple-precision" OFF)

option (ENABLE_SSE "Compile with SSE instruction set support" OFF)
option (ENABLE_SSE2 "Compile with SSE2 instruction set support" OFF)
option (ENABLE_AVX "Compile with AVX instruction set support" OFF)
option (ENABLE_AVX2 "Compile with AVX2 instruction set support" OFF)

option (DISABLE_FORTRAN "Disable Fortran wrapper routines" OFF)

include(GNUInstallDirs)


include (CheckIncludeFile)
check_include_file (alloca.h         HAVE_ALLOCA_H)
check_include_file (altivec.h        HAVE_ALTIVEC_H)
check_include_file (c_asm.h          HAVE_C_ASM_H)
check_include_file (dlfcn.h          HAVE_DLFCN_H)
check_include_file (intrinsics.h     HAVE_INTRINSICS_H)
check_include_file (inttypes.h       HAVE_INTTYPES_H)
check_include_file (libintl.h        HAVE_LIBINTL_H)
check_include_file (limits.h         HAVE_LIMITS_H)
check_include_file (mach/mach_time.h HAVE_MACH_MACH_TIME_H)
check_include_file (malloc.h         HAVE_MALLOC_H)
check_include_file (memory.h         HAVE_MEMORY_H)
check_include_file (stddef.h         HAVE_STDDEF_H)
check_include_file (stdint.h         HAVE_STDINT_H)
check_include_file (stdlib.h         HAVE_STDLIB_H)
check_include_file (string.h         HAVE_STRING_H)
check_include_file (strings.h        HAVE_STRINGS_H)
check_include_file (sys/types.h      HAVE_SYS_TYPES_H)
check_include_file (sys/time.h       HAVE_SYS_TIME_H)
check_include_file (sys/stat.h       HAVE_SYS_STAT_H)
check_include_file (sys/sysctl.h     HAVE_SYS_SYSCTL_H)
check_include_file (time.h           HAVE_TIME_H)
check_include_file (uintptr.h        HAVE_UINTPTR_H)
check_include_file (unistd.h         HAVE_UNISTD_H)
if (HAVE_TIME_H AND HAVE_SYS_TIME_H)
  set (TIME_WITH_SYS_TIME TRUE)
endif ()

include (CheckPrototypeDefinition)
check_prototype_definition (drand48 "double drand48 (void)" "0" stdlib.h HAVE_DECL_DRAND48)
check_prototype_definition (srand48 "void srand48(long int seedval)" "0" stdlib.h HAVE_DECL_SRAND48)
check_prototype_definition (cosl "long double cosl( long double arg )" "0" math.h HAVE_DECL_COSL)
check_prototype_definition (sinl "long double sinl( long double arg )" "0" math.h HAVE_DECL_SINL)
check_prototype_definition (memalign "void *memalign(size_t alignment, size_t size)" "0" malloc.h HAVE_DECL_MEMALIGN)
check_prototype_definition (posix_memalign "int posix_memalign(void **memptr, size_t alignment, size_t size)" "0" stdlib.h HAVE_DECL_POSIX_MEMALIGN)

include (CheckSymbolExists)
check_symbol_exists (clock_gettime time.h HAVE_CLOCK_GETTIME)
check_symbol_exists (gettimeofday sys/time.h HAVE_GETTIMEOFDAY)
check_symbol_exists (getpagesize unistd.h HAVE_GETPAGESIZE)
check_symbol_exists (drand48 stdlib.h HAVE_DRAND48)
check_symbol_exists (srand48 stdlib.h HAVE_SRAND48)
check_symbol_exists (memalign malloc.h HAVE_MEMALIGN)
check_symbol_exists (posix_memalign stdlib.h HAVE_POSIX_MEMALIGN)
check_symbol_exists (mach_absolute_time mach/mach_time.h HAVE_MACH_ABSOLUTE_TIME)
check_symbol_exists (alloca alloca.h HAVE_ALLOCA)
if (NOT HAVE_ALLOCA)
  unset (HAVE_ALLOCA CACHE)
  check_symbol_exists (alloca malloc.h HAVE_ALLOCA)
endif ()
check_symbol_exists (isnan math.h HAVE_ISNAN)
check_symbol_exists (snprintf stdio.h HAVE_SNPRINTF)
check_symbol_exists (strchr string.h HAVE_STRCHR)
check_symbol_exists (sysctl unistd.h HAVE_SYSCTL)

if (UNIX)
  set (CMAKE_REQUIRED_LIBRARIES m)
endif ()
check_symbol_exists (cosl math.h HAVE_COSL)
check_symbol_exists (sinl math.h HAVE_SINL)

include (CheckTypeSize)
check_type_size ("float" SIZEOF_FLOAT)
check_type_size ("double" SIZEOF_DOUBLE)
check_type_size ("int" SIZEOF_INT)
check_type_size ("long" SIZEOF_LONG)
check_type_size ("long long" SIZEOF_LONG_LONG)
check_type_size ("unsigned int" SIZEOF_UNSIGNED_INT)
check_type_size ("unsigned long" SIZEOF_UNSIGNED_LONG)
check_type_size ("unsigned long long" SIZEOF_UNSIGNED_LONG_LONG)
check_type_size ("size_t" SIZEOF_SIZE_T)
check_type_size ("ptrdiff_t" SIZEOF_PTRDIFF_T)
math (EXPR SIZEOF_INT_BITS "8 * ${SIZEOF_INT}")
set (C_FFTW_R2R_KIND "C_INT${SIZEOF_INT_BITS}_T")

find_library (LIBM_LIBRARY NAMES m)
if (LIBM_LIBRARY)
  set (HAVE_LIBM TRUE)
endif ()


if (ENABLE_THREADS)
  find_package (Threads)
endif ()
if (Threads_FOUND)
  if(CMAKE_USE_PTHREADS_INIT)
    set (USING_POSIX_THREADS 1)
  endif ()
  set (HAVE_THREADS TRUE)
endif ()

if (ENABLE_OPENMP)
  find_package (OpenMP)
endif ()
if (OPENMP_FOUND)
  set (HAVE_OPENMP TRUE)
endif ()

include (CheckCCompilerFlag)

if (ENABLE_SSE)
  foreach (FLAG "-msse" "/arch:SSE")
    unset (HAVE_SSE CACHE)
    check_c_compiler_flag (${FLAG} HAVE_SSE)
    if (HAVE_SSE)
      set (SSE_FLAG ${FLAG})
      break()
    endif ()
  endforeach ()
endif ()

if (ENABLE_SSE2)
  foreach (FLAG "-msse2" "/arch:SSE2")
    unset (HAVE_SSE2 CACHE)
    check_c_compiler_flag (${FLAG} HAVE_SSE2)
    if (HAVE_SSE2)
      set (SSE2_FLAG ${FLAG})
      break()
    endif ()
  endforeach ()
endif ()

if (ENABLE_AVX)
  foreach (FLAG "-mavx" "/arch:AVX")
    unset (HAVE_AVX CACHE)
    check_c_compiler_flag (${FLAG} HAVE_AVX)
    if (HAVE_AVX)
      set (AVX_FLAG ${FLAG})
      break()
    endif ()
  endforeach ()
endif ()

if (ENABLE_AVX2)
  foreach (FLAG "-mavx2" "/arch:AVX2")
    unset (HAVE_AVX2 CACHE)
    check_c_compiler_flag (${FLAG} HAVE_AVX2)
    if (HAVE_AVX2)
      set (AVX2_FLAG ${FLAG})
      break()
    endif ()
  endforeach ()
endif ()

# AVX2 codelets require FMA support as well
if (ENABLE_AVX2)
  foreach (FLAG "-mfma" "/arch:FMA")
    unset (HAVE_FMA CACHE)
    check_c_compiler_flag (${FLAG} HAVE_FMA)
    if (HAVE_FMA)
      set (FMA_FLAG ${FLAG})
      break()
    endif ()
  endforeach ()
endif ()

if (HAVE_SSE2 OR HAVE_AVX)
  set (HAVE_SIMD TRUE)
endif ()
file(GLOB           fftw_api_SOURCE                 api/*.c             api/*.h)
file(GLOB           fftw_dft_SOURCE                 dft/*.c             dft/*.h)
file(GLOB           fftw_dft_scalar_SOURCE          dft/scalar/*.c      dft/scalar/*.h)
file(GLOB           fftw_dft_scalar_codelets_SOURCE dft/scalar/codelets/*.c     dft/scalar/codelets/*.h)
file(GLOB           fftw_dft_simd_SOURCE            dft/simd/*.c        dft/simd/*.h)

file(GLOB           fftw_dft_simd_sse2_SOURCE       dft/simd/sse2/*.c   dft/simd/sse2/*.h)
file(GLOB           fftw_dft_simd_avx_SOURCE        dft/simd/avx/*.c    dft/simd/avx/*.h)
file(GLOB           fftw_dft_simd_avx2_SOURCE       dft/simd/avx2/*.c   dft/simd/avx2/*.h dft/simd/avx2-128/*.c   dft/simd/avx2-128/*.h)
file(GLOB           fftw_kernel_SOURCE              kernel/*.c          kernel/*.h)
file(GLOB           fftw_rdft_SOURCE                rdft/*.c            rdft/*.h)
file(GLOB           fftw_rdft_scalar_SOURCE         rdft/scalar/*.c     rdft/scalar/*.h)

file(GLOB           fftw_rdft_scalar_r2cb_SOURCE    rdft/scalar/r2cb/*.c
                                                    rdft/scalar/r2cb/*.h)
file(GLOB           fftw_rdft_scalar_r2cf_SOURCE    rdft/scalar/r2cf/*.c
                                                    rdft/scalar/r2cf/*.h)
file(GLOB           fftw_rdft_scalar_r2r_SOURCE     rdft/scalar/r2r/*.c
                                                    rdft/scalar/r2r/*.h)

file(GLOB           fftw_rdft_simd_SOURCE           rdft/simd/*.c       rdft/simd/*.h)
file(GLOB           fftw_rdft_simd_sse2_SOURCE      rdft/simd/sse2/*.c  rdft/simd/sse2/*.h)
file(GLOB           fftw_rdft_simd_avx_SOURCE       rdft/simd/avx/*.c   rdft/simd/avx/*.h)
file(GLOB           fftw_rdft_simd_avx2_SOURCE      rdft/simd/avx2/*.c  rdft/simd/avx2/*.h rdft/simd/avx2-128/*.c  rdft/simd/avx2-128/*.h)

file(GLOB           fftw_reodft_SOURCE              reodft/*.c          reodft/*.h)
file(GLOB           fftw_simd_support_SOURCE        simd-support/*.c    simd-support/*.h)
file(GLOB           fftw_libbench2_SOURCE           libbench2/*.c       libbench2/*.h)
list (REMOVE_ITEM   fftw_libbench2_SOURCE ${CMAKE_CURRENT_SOURCE_DIR}/libbench2/useropt.c)

set(SOURCEFILES
    ${fftw_api_SOURCE}
    ${fftw_dft_SOURCE}
    ${fftw_dft_scalar_SOURCE}
    ${fftw_dft_scalar_codelets_SOURCE}
    ${fftw_dft_simd_SOURCE}
    ${fftw_kernel_SOURCE}
    ${fftw_rdft_SOURCE}
    ${fftw_rdft_scalar_SOURCE}

    ${fftw_rdft_scalar_r2cb_SOURCE}
    ${fftw_rdft_scalar_r2cf_SOURCE}
    ${fftw_rdft_scalar_r2r_SOURCE}

    ${fftw_rdft_simd_SOURCE}
    ${fftw_reodft_SOURCE}
    ${fftw_simd_support_SOURCE}
    ${fftw_threads_SOURCE}
)

set(fftw_par_SOURCE
    threads/api.c
    threads/conf.c
    threads/ct.c
    threads/dft-vrank-geq1.c
    threads/f77api.c
    threads/hc2hc.c
    threads/rdft-vrank-geq1.c
    threads/vrank-geq1-rdft2.c)

set (fftw_threads_SOURCE ${fftw_par_SOURCE} threads/threads.c)
set (fftw_omp_SOURCE ${fftw_par_SOURCE} threads/openmp.c)


include_directories(.)


if (WITH_COMBINED_THREADS)
  list (APPEND SOURCEFILES ${fftw_threads_SOURCE})
endif ()


if (HAVE_SSE2)
  list (APPEND SOURCEFILES ${fftw_dft_simd_sse2_SOURCE} ${fftw_rdft_simd_sse2_SOURCE})
endif ()

if (HAVE_AVX)
  list (APPEND SOURCEFILES ${fftw_dft_simd_avx_SOURCE} ${fftw_rdft_simd_avx_SOURCE})
endif ()

if (HAVE_AVX2)
  list (APPEND SOURCEFILES ${fftw_dft_simd_avx2_SOURCE} ${fftw_rdft_simd_avx2_SOURCE})
endif ()

set (FFTW_VERSION 3.3.7)

set (PREC_SUFFIX)
#if (ENABLE_FLOAT)
  set (FFTW_SINGLE TRUE)
  set (BENCHFFT_SINGLE TRUE)
  set (PREC_SUFFIX f)
#endif ()

if (ENABLE_LONG_DOUBLE)
  set (FFTW_LDOUBLE TRUE)
  set (BENCHFFT_LDOUBLE TRUE)
  set (PREC_SUFFIX l)
endif ()

if (ENABLE_QUAD_PRECISION)
  set (FFTW_QUAD TRUE)
  set (BENCHFFT_QUAD TRUE)
  set (PREC_SUFFIX q)
endif ()
set (fftw3_lib fftw3${PREC_SUFFIX})

configure_file (cmake.config.h.in config.h @ONLY)
include_directories (${CMAKE_CURRENT_BINARY_DIR})

add_library (${fftw3_lib} STATIC ${SOURCEFILES})
target_include_directories (${fftw3_lib} INTERFACE $<INSTALL_INTERFACE:include>)
target_include_directories(${fftw3_lib} INTERFACE api)
if (MSVC)
  target_compile_options (${fftw3_lib} PRIVATE /bigobj)
endif ()
if (HAVE_SSE)
  target_compile_options (${fftw3_lib} PRIVATE ${SSE_FLAG})
endif ()
if (HAVE_SSE2)
  target_compile_options (${fftw3_lib} PRIVATE ${SSE2_FLAG})
endif ()
if (HAVE_AVX)
  target_compile_options (${fftw3_lib} PRIVATE ${AVX_FLAG})
endif ()
if (HAVE_AVX2)
  target_compile_options (${fftw3_lib} PRIVATE ${AVX2_FLAG})
endif ()
if (HAVE_FMA)
  target_compile_options (${fftw3_lib} PRIVATE ${FMA_FLAG})
endif ()
if (HAVE_LIBM)
  target_link_libraries (${fftw3_lib} m)
endif ()

set (subtargets ${fftw3_lib})

if (Threads_FOUND)
  if (WITH_COMBINED_THREADS)
    target_link_libraries (${fftw3_lib} ${CMAKE_THREAD_LIBS_INIT})
  else ()
    add_library (${fftw3_lib}_threads STATIC ${fftw_threads_SOURCE})
    target_include_directories (${fftw3_lib}_threads INTERFACE $<INSTALL_INTERFACE:include>)
    target_link_libraries (${fftw3_lib}_threads ${fftw3_lib})
    target_link_libraries (${fftw3_lib}_threads ${CMAKE_THREAD_LIBS_INIT})
    list (APPEND subtargets ${fftw3_lib}_threads)
  endif ()
endif ()

if (OPENMP_FOUND)
  add_library (${fftw3_lib}_omp STATIC ${fftw_omp_SOURCE})
  target_include_directories (${fftw3_lib}_omp INTERFACE $<INSTALL_INTERFACE:include>)
  target_link_libraries (${fftw3_lib}_omp ${fftw3_lib})
  target_link_libraries (${fftw3_lib}_omp ${CMAKE_THREAD_LIBS_INIT})
  list (APPEND subtargets ${fftw3_lib}_omp)
  target_compile_options (${fftw3_lib}_omp PRIVATE ${OpenMP_C_FLAGS})
endif ()

foreach(subtarget ${subtargets})
  set_target_properties (${subtarget} PROPERTIES SOVERSION 3.5.7 VERSION 3)
  install (TARGETS ${subtarget}
	  RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
	  LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
          ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR})
endforeach ()