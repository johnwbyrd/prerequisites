cmake_minimum_required(VERSION 3.12)
project(MissingTest LANGUAGES NONE)

# Include Prerequisite module  
list(APPEND CMAKE_MODULE_PATH "${PREREQUISITE_MODULE_DIR}")
include(Prerequisite)

# This prerequisite runs after project() to test build-time behavior
set(OUTPUT_DIR "${CMAKE_CURRENT_BINARY_DIR}/outputs")
file(MAKE_DIRECTORY "${OUTPUT_DIR}")

Prerequisite_Add(
    missing
    DOWNLOAD_COMMAND "${CMAKE_COMMAND}" -E touch "${OUTPUT_DIR}/download_output"
    BUILD_COMMAND "${CMAKE_COMMAND}" -E touch "${OUTPUT_DIR}/build_output"  
    INSTALL_COMMAND "${CMAKE_COMMAND}" -E touch "${OUTPUT_DIR}/install_output"
)

# Target that removes a stamp and then tries to build
# This should cause the removed step and subsequent steps to re-run
add_custom_target(test_missing_stamp
    # First build to create all stamps
    COMMAND "${CMAKE_COMMAND}" --build . --target missing-install
    # Remove the build post-stamp to simulate missing dependency
    COMMAND "${CMAKE_COMMAND}" -E remove -f missing-prefix/src/missing-stamp/missing-build-post
    # Remove build output to verify it gets recreated
    COMMAND "${CMAKE_COMMAND}" -E remove -f "${OUTPUT_DIR}/build_output"
    COMMAND "${CMAKE_COMMAND}" -E remove -f "${OUTPUT_DIR}/install_output"
    # Build again - should recreate missing outputs
    COMMAND "${CMAKE_COMMAND}" --build . --target missing-install
    # Verify outputs were recreated
    COMMAND "${CMAKE_COMMAND}" -P "${CMAKE_CURRENT_SOURCE_DIR}/verify_rebuild.cmake" "${OUTPUT_DIR}"
    COMMENT "Testing missing stamp triggers rebuild"
    VERBATIM
)