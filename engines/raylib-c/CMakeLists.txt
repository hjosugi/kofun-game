cmake_minimum_required(VERSION 3.20)
project(kofun_arcade_raylib C)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS OFF)

option(KOFUN_FETCH_RAYLIB "Download raylib 6.0 when it is not installed" OFF)
find_package(raylib 6.0 QUIET)

if(NOT TARGET raylib AND KOFUN_FETCH_RAYLIB)
  include(FetchContent)
  set(BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
  FetchContent_Declare(
    raylib
    GIT_REPOSITORY https://github.com/raysan5/raylib.git
    GIT_TAG 6.0
    GIT_SHALLOW TRUE
  )
  FetchContent_MakeAvailable(raylib)
endif()

if(NOT TARGET raylib)
  message(FATAL_ERROR
    "raylib 6.0 was not found. Enter the Nix shell or configure with "
    "-DKOFUN_FETCH_RAYLIB=ON.")
endif()

add_executable(kofun_arcade src/main.c)
target_link_libraries(kofun_arcade PRIVATE raylib)

if(UNIX AND NOT APPLE)
  target_link_libraries(kofun_arcade PRIVATE m)
endif()

target_compile_options(kofun_arcade PRIVATE
  $<$<C_COMPILER_ID:GNU,Clang>:-Wall -Wextra -Wpedantic>
)
