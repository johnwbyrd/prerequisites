cmake_minimum_required(VERSION 3.25)

# Include Prerequisite module
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../../../../dist/cmake")
include(Prerequisite)

# Create initial source file
set(SOURCE_DIR "${CMAKE_CURRENT_BINARY_DIR}/src")
file(MAKE_DIRECTORY "${SOURCE_DIR}")
file(WRITE "${SOURCE_DIR}/main.c" "// Initial main.c content")

# Track execution count
set(COUNT_FILE "${CMAKE_CURRENT_BINARY_DIR}/build_count.txt")
file(WRITE "${COUNT_FILE}" "0")

# Test: Basic file dependency behavior
# Question: Do file dependencies trigger rebuilds when tracked files change?
Prerequisite_Add(
    basic_file_behavior
    BUILD_DEPENDS GLOB "${SOURCE_DIR}/*.c"
    BUILD_COMMAND "${CMAKE_COMMAND}" -P "${CMAKE_CURRENT_SOURCE_DIR}/increment_count.cmake" "${COUNT_FILE}"
)

# Should execute once during configure time
message(STATUS "Phase 1: Basic file behavior test - initial execution complete")

project(BasicFileBehaviorTest LANGUAGES NONE)

# Test sequence to verify file dependency behavior
add_custom_target(test_basic_file_behavior
    # Step 1: Verify initial execution (configure time)
    COMMAND "${CMAKE_COMMAND}" -P "${CMAKE_CURRENT_SOURCE_DIR}/verify_count.cmake" "${COUNT_FILE}" "1" "initial execution"
    
    # Step 2: Build without changes - should not rebuild
    COMMAND "${CMAKE_COMMAND}" --build . --target basic_file_behavior-build
    COMMAND "${CMAKE_COMMAND}" -P "${CMAKE_CURRENT_SOURCE_DIR}/verify_count.cmake" "${COUNT_FILE}" "1" "no changes"
    
    # Step 3: Modify tracked file - should rebuild  
    COMMAND "${CMAKE_COMMAND}" -E echo "// Modified main.c content" > "${SOURCE_DIR}/main.c"
    COMMAND "${CMAKE_COMMAND}" --build . --target basic_file_behavior-build
    COMMAND "${CMAKE_COMMAND}" -P "${CMAKE_CURRENT_SOURCE_DIR}/verify_count.cmake" "${COUNT_FILE}" "2" "after modifying main.c"
    
    # Step 4: Build again without changes - should not rebuild
    COMMAND "${CMAKE_COMMAND}" --build . --target basic_file_behavior-build
    COMMAND "${CMAKE_COMMAND}" -P "${CMAKE_CURRENT_SOURCE_DIR}/verify_count.cmake" "${COUNT_FILE}" "2" "no changes after modification"
    
    COMMENT "Testing basic file dependency behavior"
)