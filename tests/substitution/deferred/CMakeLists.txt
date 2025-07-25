cmake_minimum_required(VERSION 3.12)
project(SubstitutionDeferredTest LANGUAGES NONE)

# Include Prerequisite module  
list(APPEND CMAKE_MODULE_PATH "${PREREQUISITE_MODULE_DIR}")
include(Prerequisite)

# Test variable substitution in deferred mode (after project())
set(OUTPUT_DIR "${CMAKE_CURRENT_BINARY_DIR}/outputs")
file(MAKE_DIRECTORY "${OUTPUT_DIR}")

# This should create build targets with variable substitution
Prerequisite_Add(
    substitution_deferred
    BUILD_COMMAND "${CMAKE_COMMAND}" -P "${CMAKE_CURRENT_SOURCE_DIR}/write_deferred_name.cmake" "@PREREQUISITE_NAME@" "${OUTPUT_DIR}/deferred_name.txt"
    INSTALL_COMMAND "${CMAKE_COMMAND}" -P "${CMAKE_CURRENT_SOURCE_DIR}/write_deferred_source.cmake" "@PREREQUISITE_SOURCE_DIR@" "${OUTPUT_DIR}/deferred_source.txt"
)

# Create verification target that checks substitution worked
add_custom_target(verify_deferred_substitution
    DEPENDS substitution_deferred-install
    COMMAND "${CMAKE_COMMAND}" -P "${CMAKE_CURRENT_SOURCE_DIR}/verify_deferred.cmake" "${OUTPUT_DIR}"
    COMMENT "Verifying variable substitution in deferred mode"
)