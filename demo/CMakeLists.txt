cmake_minimum_required(VERSION 3.10)

project(MatrixAcceleratorDemo VERSION 1.0)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

file(GLOB_RECURSE SOURCE_FILES "${CMAKE_SOURCE_DIR}/src/*.cpp")

file(GLOB_RECURSE HEADER_FILES "${CMAKE_SOURCE_DIR}/include/*.hpp")

add_executable(${PROJECT_NAME} ${SOURCE_FILES} ${HEADER_FILES})

target_include_directories(${PROJECT_NAME} PRIVATE "${CMAKE_SOURCE_DIR}/include")
