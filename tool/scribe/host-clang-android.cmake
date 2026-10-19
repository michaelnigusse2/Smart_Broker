# CMake toolchain: build Android binaries with a host clang/lld (Linux) and the
# headers + libraries of an Android NDK (no NDK compilers needed), as used for
# the Addis Scribe trial. Set before configuring:
#   ANDROID_ABI      arm64-v8a | x86_64
#   NDK_SYSROOT      <ndk>/toolchains/llvm/prebuilt/<host>/sysroot
#   CLANG_RESOURCES  dir with include/ (host clang's builtin headers) and
#                    lib/linux/ (the NDK's libclang_rt.builtins-*-android.a, */libunwind.a)
# On a machine with the full NDK and CMake >= 3.26, prefer the NDK's own
# build/cmake/android.toolchain.cmake (-DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=28).
set(CMAKE_SYSTEM_NAME Linux)
if("$ENV{ANDROID_ABI}" STREQUAL "x86_64")
  set(CMAKE_SYSTEM_PROCESSOR x86_64)
else()
  set(CMAKE_SYSTEM_PROCESSOR aarch64)
endif()
set(_TRIPLE ${CMAKE_SYSTEM_PROCESSOR}-linux-android28)
set(CMAKE_C_COMPILER clang)
set(CMAKE_CXX_COMPILER clang++)
set(CMAKE_C_COMPILER_TARGET ${_TRIPLE})
set(CMAKE_CXX_COMPILER_TARGET ${_TRIPLE})
set(CMAKE_SYSROOT $ENV{NDK_SYSROOT})
set(_RES $ENV{CLANG_RESOURCES})
set(CMAKE_C_FLAGS_INIT "-resource-dir=${_RES} -fPIC")
set(CMAKE_CXX_FLAGS_INIT "-resource-dir=${_RES} -fPIC -stdlib=libc++")
# Static libc++ (no libc++_shared.so to ship), 16 KB pages (required by Google
# Play for Android 15+ devices), liblog for __android_log_write.
set(_LD "-fuse-ld=lld -resource-dir=${_RES} -stdlib=libc++ -static-libstdc++ -rtlib=compiler-rt -unwindlib=libunwind -Wl,--build-id=sha1 -Wl,-z,max-page-size=16384 -llog")
set(CMAKE_EXE_LINKER_FLAGS_INIT "${_LD} -pie")
set(CMAKE_SHARED_LINKER_FLAGS_INIT "${_LD}")
set(CMAKE_MODULE_LINKER_FLAGS_INIT "${_LD}")
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY BOTH)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE BOTH)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE BOTH)
