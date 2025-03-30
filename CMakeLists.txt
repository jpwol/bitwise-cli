cmake_minimum_required(VERSION 3.10)
project(bitline)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

file(GLOB SRC_FILES "src/*.c")
set(BIN_DIR "${CMAKE_SOURCE_DIR}/bin")
make_directory(${BIN_DIR})
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${BIN_DIR})

add_executable(bitline ${SRC_FILES})

target_include_directories(bitline PRIVATE include)
