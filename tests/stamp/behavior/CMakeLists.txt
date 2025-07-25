cmake_minimum_required(VERSION 3.12)

# Include Prerequisite module
list(APPEND CMAKE_MODULE_PATH "${PREREQUISITE_MODULE_DIR}")
include(Prerequisite)

# Create execution tracking directory
set(TRACK_DIR "${CMAKE_CURRENT_BINARY_DIR}/execution_tracking")
file(MAKE_DIRECTORY "${TRACK_DIR}")

# Test: Prerequisite that writes to files to track execution count
# This allows us to verify that stamp files prevent unnecessary reruns
Prerequisite_Add(
    behavior
    DOWNLOAD_COMMAND "${CMAKE_COMMAND}" -E touch "${TRACK_DIR}/download_executed"
    BUILD_COMMAND "${CMAKE_COMMAND}" -E touch "${TRACK_DIR}/build_executed"  
    INSTALL_COMMAND "${CMAKE_COMMAND}" -E touch "${TRACK_DIR}/install_executed"
)

# This should execute during configuration since we're before project()
message(STATUS "Test: behavior configuration complete")

project(BehaviorTest LANGUAGES NONE)

# Create a target to test build-time execution
add_custom_target(test_stamps
    DEPENDS behavior-install
    COMMAND ${CMAKE_COMMAND} -E echo "All steps completed"
)