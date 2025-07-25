cmake_minimum_required(VERSION 3.12)
project(DeferredTest LANGUAGES NONE)

# Include Prerequisite module
list(APPEND CMAKE_MODULE_PATH "${PREREQUISITE_MODULE_DIR}")
include(Prerequisite)

# Test: Simple deferred prerequisite that uses CMake for cross-platform compatibility
Prerequisite_Add(
    deferred
    DOWNLOAD_COMMAND "${CMAKE_COMMAND}" -E echo "Hello from deferred prerequisite download step"
    BUILD_COMMAND "${CMAKE_COMMAND}" -E echo "Hello from deferred prerequisite build step"
)

# This should create a build target
message(STATUS "Test: deferred configuration complete")

# Add a custom target that depends on the prerequisite to verify it exists
add_custom_target(test_depends_on_prerequisite
    DEPENDS prerequisite_deferred
    COMMAND ${CMAKE_COMMAND} -E echo "Prerequisite completed successfully"
)