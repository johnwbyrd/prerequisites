cmake_minimum_required(VERSION 3.12)

# Include Prerequisite module
list(APPEND CMAKE_MODULE_PATH "${PREREQUISITE_MODULE_DIR}")
include(Prerequisite)

# This test checks that reconfiguration respects existing stamps
set(EXECUTION_MARKER "${CMAKE_CURRENT_BINARY_DIR}/execution_marker.txt")

# Create marker file that tracks total executions across reconfigurations
if(NOT EXISTS "${EXECUTION_MARKER}")
    file(WRITE "${EXECUTION_MARKER}" "0")
endif()

# Read current execution count
file(READ "${EXECUTION_MARKER}" EXEC_COUNT)
string(STRIP "${EXEC_COUNT}" EXEC_COUNT)
if(NOT EXEC_COUNT MATCHES "^[0-9]+$")
    set(EXEC_COUNT 0)
endif()

Prerequisite_Add(
    reconfig
    DOWNLOAD_COMMAND "${CMAKE_COMMAND}" -P "${CMAKE_CURRENT_SOURCE_DIR}/track_execution.cmake" "${EXECUTION_MARKER}"
    BUILD_COMMAND "${CMAKE_COMMAND}" -E echo "Build step executed"
)

# After first run, the marker should show executions
# After reconfigure, it should NOT increment if stamps work
file(READ "${EXECUTION_MARKER}" FINAL_COUNT)
string(STRIP "${FINAL_COUNT}" FINAL_COUNT)

message(STATUS "Prerequisite execution count: ${FINAL_COUNT}")

project(ReconfigTest LANGUAGES NONE)

# This target will fail if executions > 1 (meaning stamps didn't work)
add_custom_target(verify_reconfig
    COMMAND "${CMAKE_COMMAND}" -P "${CMAKE_CURRENT_SOURCE_DIR}/check_reconfig.cmake" "${EXECUTION_MARKER}"
    COMMENT "Verifying reconfiguration respected stamps"
)