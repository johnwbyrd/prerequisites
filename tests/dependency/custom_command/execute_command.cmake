# Script to execute the command and record evidence
# Usage: cmake -P execute_command.cmake <counter_file> <output_file> <timestamp_file>

if(NOT CMAKE_ARGC EQUAL 6)
    message(FATAL_ERROR "Usage: cmake -P execute_command.cmake <counter_file> <output_file> <timestamp_file>")
endif()

set(COUNTER_FILE "${CMAKE_ARGV3}")
set(OUTPUT_FILE "${CMAKE_ARGV4}")
set(TIMESTAMP_FILE "${CMAKE_ARGV5}")

# Read current count
if(EXISTS "${COUNTER_FILE}")
    file(READ "${COUNTER_FILE}" CURRENT_COUNT)
    string(STRIP "${CURRENT_COUNT}" CURRENT_COUNT)
    if(NOT CURRENT_COUNT MATCHES "^[0-9]+$")
        set(CURRENT_COUNT 0)
    endif()
else()
    set(CURRENT_COUNT 0)
endif()

# Increment and write back
math(EXPR NEW_COUNT "${CURRENT_COUNT} + 1")
file(WRITE "${COUNTER_FILE}" "${NEW_COUNT}")

# Get current timestamp
file(TIMESTAMP "${CMAKE_CURRENT_BINARY_DIR}/." execution_timestamp "%Y-%m-%d %H:%M:%S.%3N")

# Record execution in timestamp file
file(APPEND "${TIMESTAMP_FILE}" "EXECUTION: ${execution_timestamp} (count: ${NEW_COUNT})\n")

# Create output file with execution evidence
file(WRITE "${OUTPUT_FILE}" "Output file modified at ${execution_timestamp} (execution #${NEW_COUNT})\n")
file(APPEND "${OUTPUT_FILE}" "Dependency file was created at an earlier time.\n")

message(STATUS "EXECUTION: Custom command executed (count: ${NEW_COUNT})")
message(STATUS "         Output file modified at: ${execution_timestamp}")
