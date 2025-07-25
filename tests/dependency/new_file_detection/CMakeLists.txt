cmake_minimum_required(VERSION 3.25)

# Include Prerequisite module
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../../../../dist/cmake")
include(Prerequisite)

# Create initial source files
set(SOURCE_DIR "${CMAKE_CURRENT_BINARY_DIR}/src")
file(MAKE_DIRECTORY "${SOURCE_DIR}")
file(WRITE "${SOURCE_DIR}/existing.c" "// Existing file")

# Track execution count
set(COUNT_FILE "${CMAKE_CURRENT_BINARY_DIR}/build_count.txt")
file(WRITE "${COUNT_FILE}" "0")

# Test: New file detection behavior
# Question: Do file dependencies work with newly added files that match glob patterns?
Prerequisite_Add(
    new_file_detection
    BUILD_DEPENDS GLOB "${SOURCE_DIR}/*.c"
    BUILD_COMMAND "${CMAKE_COMMAND}" -P "${CMAKE_CURRENT_SOURCE_DIR}/increment_count.cmake" "${COUNT_FILE}"
)

message(STATUS "Phase 2: New file detection test - initial execution complete")

project(NewFileDetectionTest LANGUAGES NONE)

# Test sequence to verify new file detection
add_custom_target(test_new_file_detection
    # Step 1: Verify initial execution
    COMMAND "${CMAKE_COMMAND}" -P "${CMAKE_CURRENT_SOURCE_DIR}/verify_count.cmake" "${COUNT_FILE}" "1" "initial execution"
    
    # Step 2: Add new file matching glob pattern
    COMMAND "${CMAKE_COMMAND}" -E echo "// New file content" > "${SOURCE_DIR}/new_file.c"
    
    # Step 3: Build - critical test: does it detect the new file?
    COMMAND "${CMAKE_COMMAND}" --build . --target new_file_detection-build
    COMMAND "${CMAKE_COMMAND}" -P "${CMAKE_CURRENT_SOURCE_DIR}/analyze_new_file_result.cmake" "${COUNT_FILE}"
    
    COMMENT "Testing new file detection behavior - answers whether globs are resolved at configure vs build time"
)