# minimum version of CMake.
cmake_minimum_required(VERSION 3.5.0)
project(hish)
set(PROJECT_LANGUAGE C)
if(DEFINED CMAKE_CXX_COMPILER)
  set(CMAKE_CXX_STANDARD 17)
  list(APPEND PROJECT_LANGUAGES CXX)
endif(DEFINED CMAKE_CXX_COMPILER)

project(HiSH VERSION 1.0.0 LANGUAGES ${PROJECT_LANGUAGES})

set(NATIVERENDER_ROOT_PATH ${CMAKE_CURRENT_SOURCE_DIR})

if(DEFINED PACKAGE_FIND_FILE)
    include(${PACKAGE_FIND_FILE})
endif()

# Include directories
include_directories(
    ${NATIVERENDER_ROOT_PATH}
    ${NATIVERENDER_ROOT_PATH}/include
)

# HiSH sources (VNC removed — only napi_init.cpp needed)
add_library(hish_main SHARED
    napi_init.cpp
)

target_link_libraries(hish_main PUBLIC
    libace_napi.z.so
    libhilog_ndk.z.so
)
