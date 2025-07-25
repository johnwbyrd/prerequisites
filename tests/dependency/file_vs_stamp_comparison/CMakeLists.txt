cmake_minimum_required(VERSION 3.12)

# Include Prerequisite module
list(APPEND CMAKE_MODULE_PATH "${PREREQUISITE_MODULE_DIR}")
include(Prerequisite)

# Create source files
set(SOURCE_DIR "${CMAKE_CURRENT_BINARY_DIR}/src")
file(MAKE_DIRECTORY "${SOURCE_DIR}")
file(WRITE "${SOURCE_DIR}/source.c" "// Source file")

# Track execution counts for both approaches
set(FILE_COUNT "${CMAKE_CURRENT_BINARY_DIR}/file_count.txt")
set(STAMP_COUNT "${CMAKE_CURRENT_BINARY_DIR}/stamp_count.txt")
file(WRITE "${FILE_COUNT}" "0")
file(WRITE "${STAMP_COUNT}" "0")

# Test: Direct comparison of file vs stamp dependency behavior
# Question: What are the exact behavioral differences?

# File-based dependency tracking
Prerequisite_Add(
    file_based
    BUILD_DEPENDS GLOB "${SOURCE_DIR}/*.c"
    BUILD_COMMAND "${CMAKE_COMMAND}" -P "${CMAKE_CURRENT_SOURCE_DIR}/increment_file_count.cmake" "${FILE_COUNT}"
)

# Stamp-based dependency tracking (no file dependencies)
Prerequisite_Add(
    stamp_based
    BUILD_COMMAND "${CMAKE_COMMAND}" -P "${CMAKE_CURRENT_SOURCE_DIR}/increment_stamp_count.cmake" "${STAMP_COUNT}"
)

message(STATUS "Phase 4: File vs stamp comparison - initial execution complete")

project(FileVsStampComparisonTest LANGUAGES NONE)

# Direct comparison test
add_custom_target(test_file_vs_stamp_comparison
    # Step 1: Verify both executed once initially
    COMMAND "${CMAKE_COMMAND}" -P "${CMAKE_CURRENT_SOURCE_DIR}/verify_both_counts.cmake" "${FILE_COUNT}" "${STAMP_COUNT}" "1" "1" "initial execution"
    
    # Step 2: Build both without changes - neither should rebuild
    COMMAND "${CMAKE_COMMAND}" --build . --target file_based-build
    COMMAND "${CMAKE_COMMAND}" --build . --target stamp_based-build
    COMMAND "${CMAKE_COMMAND}" -P "${CMAKE_CURRENT_SOURCE_DIR}/verify_both_counts.cmake" "${FILE_COUNT}" "${STAMP_COUNT}" "1" "1" "no changes"
    
    # Step 3: Modify source file - only file-based should rebuild
    COMMAND "${CMAKE_COMMAND}" -E echo "// Modified source file" > "${SOURCE_DIR}/source.c"
    COMMAND "${CMAKE_COMMAND}" --build . --target file_based-build
    COMMAND "${CMAKE_COMMAND}" --build . --target stamp_based-build
    COMMAND "${CMAKE_COMMAND}" -P "${CMAKE_CURRENT_SOURCE_DIR}/verify_both_counts.cmake" "${FILE_COUNT}" "${STAMP_COUNT}" "2" "1" "after file modification"
    
    COMMENT "Direct comparison of file-based vs stamp-based dependency tracking"
)