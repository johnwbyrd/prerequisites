cmake_minimum_required(VERSION 3.25)

# Include Prerequisite module
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../../../../dist/cmake")
include(Prerequisite)

# Test: Verify prerequisites execute immediately during configure time
# This test creates marker files to prove execution happens before project()

set(DOWNLOAD_MARKER "${CMAKE_CURRENT_BINARY_DIR}/download_executed.txt")
set(BUILD_MARKER "${CMAKE_CURRENT_BINARY_DIR}/build_executed.txt")
set(INSTALL_MARKER "${CMAKE_CURRENT_BINARY_DIR}/install_executed.txt")

# Clean any existing markers
file(REMOVE "${DOWNLOAD_MARKER}" "${BUILD_MARKER}" "${INSTALL_MARKER}")

# Define prerequisite that creates marker files
Prerequisite_Add(
    immediate
    DOWNLOAD_COMMAND "${CMAKE_COMMAND}" -E touch "${DOWNLOAD_MARKER}"
    BUILD_COMMAND "${CMAKE_COMMAND}" -E touch "${BUILD_MARKER}"
    INSTALL_COMMAND "${CMAKE_COMMAND}" -E touch "${INSTALL_MARKER}"
)

# Verify files were created immediately (before project() call)
foreach(marker DOWNLOAD_MARKER BUILD_MARKER INSTALL_MARKER)
    if(NOT EXISTS "${${marker}}")
        message(FATAL_ERROR "IMMEDIATE EXECUTION FAILURE: ${marker} was not created - ${marker} did not execute immediately")
    endif()
endforeach()

message(STATUS "SUCCESS: All prerequisite steps executed immediately during configure time")

# NOW call project() - prerequisite should already be complete
project(ImmediateTest LANGUAGES NONE)

# Final verification - files should still exist
foreach(marker DOWNLOAD_MARKER BUILD_MARKER INSTALL_MARKER)
    if(NOT EXISTS "${${marker}}")
        message(FATAL_ERROR "POST-PROJECT FAILURE: ${marker} disappeared after project() call")
    endif()
endforeach()

message(STATUS "Test passed: Immediate execution verified")