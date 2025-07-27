# Wrapper script for verifying counters from command line
# Usage: cmake -P verify_counter_wrapper.cmake <counter_file> <expected_count> <description>

if(NOT CMAKE_ARGC EQUAL 6)
    message(FATAL_ERROR "Usage: cmake -P verify_counter_wrapper.cmake <counter_file> <expected_count> <description>")
endif()

set(COUNTER_FILE "${CMAKE_ARGV3}")
set(EXPECTED_COUNT "${CMAKE_ARGV4}")
set(DESCRIPTION "${CMAKE_ARGV5}")

# Include the counter utilities
get_filename_component(SCRIPT_DIR "${CMAKE_CURRENT_LIST_FILE}" DIRECTORY)
include("${SCRIPT_DIR}/counter_file.cmake")

# Verify the counter
verify_counter_file("${COUNTER_FILE}" "${EXPECTED_COUNT}" "${DESCRIPTION}")