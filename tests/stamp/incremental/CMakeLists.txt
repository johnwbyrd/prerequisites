cmake_minimum_required(VERSION 3.25)

# Include Prerequisite module
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../../../../dist/cmake")
include(Prerequisite)

# Create execution tracking with counters that will fail if commands run multiple times
set(TRACK_DIR "${CMAKE_CURRENT_BINARY_DIR}/execution_count")
file(MAKE_DIRECTORY "${TRACK_DIR}")

# Initialize counter files to 0
file(WRITE "${TRACK_DIR}/download_count" "0")
file(WRITE "${TRACK_DIR}/build_count" "0")
file(WRITE "${TRACK_DIR}/install_count" "0")

# Commands that increment counters - if run twice, count will be > 1
Prerequisite_Add(
    incremental
    DOWNLOAD_COMMAND "${CMAKE_COMMAND}" -P "${CMAKE_CURRENT_SOURCE_DIR}/increment_counter.cmake" "${TRACK_DIR}/download_count"
    BUILD_COMMAND "${CMAKE_COMMAND}" -P "${CMAKE_CURRENT_SOURCE_DIR}/increment_counter.cmake" "${TRACK_DIR}/build_count"
    INSTALL_COMMAND "${CMAKE_COMMAND}" -P "${CMAKE_CURRENT_SOURCE_DIR}/increment_counter.cmake" "${TRACK_DIR}/install_count"
)

# This executes during configuration - should run commands once
message(STATUS "Configuration complete")

project(IncrementalTest LANGUAGES NONE)

# Custom target to trigger build-time execution
add_custom_target(verify_no_rerun
    DEPENDS incremental-install
    COMMAND "${CMAKE_COMMAND}" -P "${CMAKE_CURRENT_SOURCE_DIR}/verify_counts.cmake" "${TRACK_DIR}"
    COMMENT "Verifying prerequisites didn't re-run unnecessarily"
)