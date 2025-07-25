cmake_minimum_required(VERSION 3.25)

# Include Prerequisite module
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../../../../dist/cmake")
include(Prerequisite)

# Test variable substitution in immediate mode (before project())
set(OUTPUT_DIR "${CMAKE_CURRENT_BINARY_DIR}/outputs")
file(MAKE_DIRECTORY "${OUTPUT_DIR}")

# This should execute immediately with variable substitution
Prerequisite_Add(
    substitution_immediate
    BUILD_COMMAND "${CMAKE_COMMAND}" -P "${CMAKE_CURRENT_SOURCE_DIR}/write_name.cmake" "@PREREQUISITE_NAME@" "${OUTPUT_DIR}/name.txt"
    INSTALL_COMMAND "${CMAKE_COMMAND}" -P "${CMAKE_CURRENT_SOURCE_DIR}/write_binary_dir.cmake" "@PREREQUISITE_BINARY_DIR@" "${OUTPUT_DIR}/binary_dir.txt"
)

# Verify files were created with substituted values
if(NOT EXISTS "${OUTPUT_DIR}/name.txt")
    message(FATAL_ERROR "SUBSTITUTION FAILURE: name.txt not created during immediate execution")
endif()

if(NOT EXISTS "${OUTPUT_DIR}/binary_dir.txt")
    message(FATAL_ERROR "SUBSTITUTION FAILURE: binary_dir.txt not created during immediate execution")
endif()

# Check file contents
file(READ "${OUTPUT_DIR}/name.txt" name_content)
string(STRIP "${name_content}" name_content)
if(NOT name_content STREQUAL "Name: substitution_immediate")
    message(FATAL_ERROR "SUBSTITUTION FAILURE: Expected 'Name: substitution_immediate', got '${name_content}'")
endif()

file(READ "${OUTPUT_DIR}/binary_dir.txt" binary_content)
string(STRIP "${binary_content}" binary_content)
if(NOT binary_content MATCHES "Binary dir: .*/substitution_immediate-prefix/src/substitution_immediate-build")
    message(FATAL_ERROR "SUBSTITUTION FAILURE: Binary dir not substituted correctly: '${binary_content}'")
endif()

message(STATUS "SUCCESS: Variable substitution working in immediate mode")

project(SubstitutionImmediateTest LANGUAGES NONE)