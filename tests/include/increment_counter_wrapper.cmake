# Wrapper script for incrementing counters from command line
# Usage: cmake -P increment_counter_wrapper.cmake <counter_file>

if(NOT CMAKE_ARGC EQUAL 4)
    message(FATAL_ERROR "Usage: cmake -P increment_counter_wrapper.cmake <counter_file>")
endif()

set(COUNTER_FILE "${CMAKE_ARGV3}")

# Include the counter utilities
get_filename_component(SCRIPT_DIR "${CMAKE_CURRENT_LIST_FILE}" DIRECTORY)
include("${SCRIPT_DIR}/counter_file.cmake")

# Increment the counter
increment_counter_file("${COUNTER_FILE}")