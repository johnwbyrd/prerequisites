cmake_minimum_required(VERSION 3.12)

# Include Prerequisite module
list(APPEND CMAKE_MODULE_PATH "${PREREQUISITE_MODULE_DIR}")
include(Prerequisite)

# Create test source files to track
set(SOURCE_DIR "${CMAKE_CURRENT_BINARY_DIR}/test_sources")
file(MAKE_DIRECTORY "${SOURCE_DIR}")
file(WRITE "${SOURCE_DIR}/source1.c" "// Test source file 1")
file(WRITE "${SOURCE_DIR}/source2.c" "// Test source file 2") 
file(WRITE "${SOURCE_DIR}/header.h" "// Test header file")

# Create output tracking
set(OUTPUT_DIR "${CMAKE_CURRENT_BINARY_DIR}/outputs")
file(MAKE_DIRECTORY "${OUTPUT_DIR}")

# Test prerequisite with file dependencies
Prerequisite_Add(
    file_deps
    # Build step depends on source files
    BUILD_DEPENDS GLOB "${SOURCE_DIR}/*.c" "${SOURCE_DIR}/*.h"
    BUILD_COMMAND "${CMAKE_COMMAND}" -E touch "${OUTPUT_DIR}/build_output"
    INSTALL_COMMAND "${CMAKE_COMMAND}" -E touch "${OUTPUT_DIR}/install_output"
)

# This executes during configuration
message(STATUS "Test: file_deps configuration complete")

project(FileDepsTest LANGUAGES NONE)

# Target to test file dependency behavior
add_custom_target(test_file_deps
    DEPENDS file_deps-install
    COMMAND "${CMAKE_COMMAND}" -P "${CMAKE_CURRENT_SOURCE_DIR}/verify_file_deps.cmake" "${OUTPUT_DIR}" "${SOURCE_DIR}"
    COMMENT "Testing file dependency tracking"
)