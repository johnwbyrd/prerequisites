cmake_minimum_required(VERSION 3.12)

# Include Prerequisite module
list(APPEND CMAKE_MODULE_PATH "${PREREQUISITE_MODULE_DIR}")
include(Prerequisite)

# Create source files - some tracked, some not
set(SOURCE_DIR "${CMAKE_CURRENT_BINARY_DIR}/src")
file(MAKE_DIRECTORY "${SOURCE_DIR}")
file(WRITE "${SOURCE_DIR}/tracked.c" "// Tracked file")
file(WRITE "${SOURCE_DIR}/untracked.h" "// Untracked header file") 
file(WRITE "${SOURCE_DIR}/untracked.txt" "// Untracked text file")

# Include counter file utilities
include("${PREREQUISITE_TEST_UTILS_DIR}/counter_file.cmake")

# Track execution count
set(COUNT_FILE "${CMAKE_CURRENT_BINARY_DIR}/build_count.txt")
init_counter_file("${COUNT_FILE}")

# Test: Untracked file behavior
# Question: Do untracked files (not matching glob) correctly NOT trigger rebuilds?
Prerequisite_Add(
    untracked_file_behavior
    BUILD_DEPENDS GLOB "${SOURCE_DIR}/*.c"  # Only tracks .c files
    BUILD_COMMAND "${CMAKE_COMMAND}" -P "${CMAKE_CURRENT_SOURCE_DIR}/increment_count.cmake" "${COUNT_FILE}"
)

message(STATUS "Phase 3: Untracked file behavior test - initial execution complete")

project(UntrackedFileBehaviorTest LANGUAGES NONE)

# Test sequence to verify untracked files are ignored
add_custom_target(test_untracked_file_behavior
    # Step 1: Verify initial execution
    COMMAND "${CMAKE_COMMAND}" -P "${CMAKE_CURRENT_SOURCE_DIR}/verify_count.cmake" "${COUNT_FILE}" "1" "initial execution"
    
    # Step 2: Modify untracked .h file - should NOT rebuild
    COMMAND "${CMAKE_COMMAND}" -E echo "// Modified untracked header" > "${SOURCE_DIR}/untracked.h"
    COMMAND "${CMAKE_COMMAND}" --build . --target untracked_file_behavior-build
    COMMAND "${CMAKE_COMMAND}" -P "${CMAKE_CURRENT_SOURCE_DIR}/verify_count.cmake" "${COUNT_FILE}" "1" "after modifying untracked .h file"
    
    # Step 3: Modify untracked .txt file - should NOT rebuild
    COMMAND "${CMAKE_COMMAND}" -E echo "// Modified untracked text" > "${SOURCE_DIR}/untracked.txt"
    COMMAND "${CMAKE_COMMAND}" --build . --target untracked_file_behavior-build
    COMMAND "${CMAKE_COMMAND}" -P "${CMAKE_CURRENT_SOURCE_DIR}/verify_count.cmake" "${COUNT_FILE}" "1" "after modifying untracked .txt file"
    
    # Step 4: Modify tracked .c file - SHOULD rebuild
    COMMAND "${CMAKE_COMMAND}" -E echo "// Modified tracked file" > "${SOURCE_DIR}/tracked.c"
    COMMAND "${CMAKE_COMMAND}" --build . --target untracked_file_behavior-build
    COMMAND "${CMAKE_COMMAND}" -P "${CMAKE_CURRENT_SOURCE_DIR}/verify_count.cmake" "${COUNT_FILE}" "2" "after modifying tracked .c file"
    
    COMMENT "Testing that untracked files correctly do not trigger rebuilds"
)