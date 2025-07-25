# Prerequisites Test Suite
cmake_minimum_required(VERSION 3.12)
project(PrerequisiteTests LANGUAGES NONE)

# Enable testing
enable_testing()

# Set up test environment variables
set(PREREQUISITE_TEST_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}")
set(PREREQUISITE_TEST_BINARY_DIR "${CMAKE_CURRENT_BINARY_DIR}")

# Set up module path for tests
set(PREREQUISITE_MODULE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../cmake" CACHE PATH "Path to Prerequisite module directory")

# Function to add a prerequisite test with process isolation
function(add_prerequisite_test TEST_NAME)
    set(options EXPECT_FAIL)
    set(oneValueArgs TIMEOUT)
    set(multiValueArgs COMMAND CONFIG_ARGS)
    cmake_parse_arguments(APT "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
    
    # Default timeout
    if(NOT APT_TIMEOUT)
        set(APT_TIMEOUT 30)
    endif()
    
    # Create test directory
    set(TEST_DIR "${CMAKE_CURRENT_BINARY_DIR}/${TEST_NAME}")
    file(MAKE_DIRECTORY "${TEST_DIR}")
    
    # Create the test
    add_test(
        NAME ${TEST_NAME}
        COMMAND ${CMAKE_COMMAND}
            ${APT_CONFIG_ARGS}
            -DPREREQUISITE_MODULE_DIR=${PREREQUISITE_MODULE_DIR}
            -D_PREREQUISITE_DEBUG=TRUE
            --debug-output
            "${CMAKE_CURRENT_SOURCE_DIR}/${TEST_NAME}"
        WORKING_DIRECTORY "${TEST_DIR}"
    )
    
    # Set test properties
    set_tests_properties(${TEST_NAME} PROPERTIES
        TIMEOUT ${APT_TIMEOUT}
        ENVIRONMENT "CTEST_OUTPUT_ON_FAILURE=1"
    )
    
    if(APT_EXPECT_FAIL)
        set_tests_properties(${TEST_NAME} PROPERTIES WILL_FAIL TRUE)
    endif()
    
    # Add build test if requested
    if(APT_COMMAND)
        add_test(
            NAME ${TEST_NAME}_build
            COMMAND ${CMAKE_COMMAND}
                --build "${TEST_DIR}"
                ${APT_COMMAND}
            WORKING_DIRECTORY "${TEST_DIR}"
        )
        set_tests_properties(${TEST_NAME}_build PROPERTIES
            DEPENDS ${TEST_NAME}
            TIMEOUT ${APT_TIMEOUT}
            ENVIRONMENT "CTEST_OUTPUT_ON_FAILURE=1"
        )
    endif()
endfunction()

# Simple functionality tests
add_prerequisite_test(simple/immediate)
add_prerequisite_test(simple/deferred COMMAND --target deferred-build)

# Stamp file behavior tests
add_prerequisite_test(stamp/behavior COMMAND --target test_stamps)

# Advanced stamp behavior tests that will FAIL if stamps don't work
add_prerequisite_test(stamp/incremental COMMAND --target verify_no_rerun)
add_prerequisite_test(stamp/reconfig COMMAND --target verify_reconfig) 
add_prerequisite_test(stamp/missing COMMAND --target test_missing_stamp)

# File dependency tracking tests
add_prerequisite_test(stamp/file_deps COMMAND --target test_file_deps)
add_prerequisite_test(stamp/file_timestamp COMMAND --target test_timestamp_behavior)

# Variable substitution tests
add_prerequisite_test(substitution/immediate)
add_prerequisite_test(substitution/deferred COMMAND --target verify_deferred_substitution)

# Systematic dependency tracking behavior tests
add_prerequisite_test(dependency/basic_file_behavior COMMAND --target test_basic_file_behavior)
add_prerequisite_test(dependency/new_file_detection COMMAND --target test_new_file_detection) 
add_prerequisite_test(dependency/untracked_file_behavior COMMAND --target test_untracked_file_behavior)
add_prerequisite_test(dependency/file_vs_stamp_comparison COMMAND --target test_file_vs_stamp_comparison)