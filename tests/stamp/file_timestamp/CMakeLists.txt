cmake_minimum_required(VERSION 3.12)

# Include Prerequisite module
list(APPEND CMAKE_MODULE_PATH "${PREREQUISITE_MODULE_DIR}")
include(Prerequisite)

# Create test source file
set(SOURCE_DIR "${CMAKE_CURRENT_BINARY_DIR}/sources")
file(MAKE_DIRECTORY "${SOURCE_DIR}")
file(WRITE "${SOURCE_DIR}/test.c" "// Initial version")

# Include counter file utilities
include("${PREREQUISITE_TEST_UTILS_DIR}/counter_file.cmake")

# Track execution count
set(COUNT_FILE "${CMAKE_CURRENT_BINARY_DIR}/execution_count")
init_counter_file("${COUNT_FILE}")

# Test prerequisite with file dependencies that tracks executions
Prerequisite_Add(
    file_timestamp
    BUILD_DEPENDS GLOB "${SOURCE_DIR}/*.c"
    BUILD_COMMAND "${CMAKE_COMMAND}" -P "${CMAKE_CURRENT_SOURCE_DIR}/increment_and_check.cmake" "${COUNT_FILE}"
)

message(STATUS "Test: file_timestamp configuration complete")

project(FileTimestampTest LANGUAGES NONE)

# Target to test timestamp behavior
add_custom_target(test_timestamp_behavior
    DEPENDS file_timestamp-build
    COMMAND "${CMAKE_COMMAND}" -P "${CMAKE_CURRENT_SOURCE_DIR}/verify_timestamp.cmake" "${COUNT_FILE}" "${SOURCE_DIR}"
    COMMENT "Testing file timestamp tracking"
)