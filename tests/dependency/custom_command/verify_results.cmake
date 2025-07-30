# Script to verify the results of the test
# Usage: cmake -P verify_results.cmake <counter_file> <timestamp_file>

if(NOT CMAKE_ARGC EQUAL 5)
    message(FATAL_ERROR "Usage: cmake -P verify_results.cmake <counter_file> <timestamp_file>")
endif()

set(COUNTER_FILE "${CMAKE_ARGV3}")
set(TIMESTAMP_FILE "${CMAKE_ARGV4}")

# Read counter
if(EXISTS "${COUNTER_FILE}")
    file(READ "${COUNTER_FILE}" COUNT)
    string(STRIP "${COUNT}" COUNT)
    if(NOT COUNT MATCHES "^[0-9]+$")
        set(COUNT 0)
    endif()
else()
    set(COUNT 0)
endif()

# Read timestamps
if(EXISTS "${TIMESTAMP_FILE}")
    file(READ "${TIMESTAMP_FILE}" timestamps_content)
else()
    set(timestamps_content "")
endif()

# Parse timestamps
string(REGEX MATCH "DEPENDENCY: ([^\n]*)" dependency_match "${timestamps_content}")
set(dependency_timestamp "${CMAKE_MATCH_1}")

string(REGEX MATCH "OUTPUT: ([^\n]*)" output_match "${timestamps_content}")
set(output_timestamp "${CMAKE_MATCH_1}")

string(REGEX MATCH "EXECUTION: ([^\n]*)" execution_match "${timestamps_content}")
set(execution_timestamp "${CMAKE_MATCH_1}")

# Report raw data without interpretation
message(STATUS "TEST RESULTS:")
message(STATUS "-------------")
message(STATUS "Dependency file timestamp: ${dependency_timestamp}")
message(STATUS "Output file timestamp: ${output_timestamp}")
message(STATUS "Command execution timestamp: ${execution_timestamp}")
message(STATUS "Command executed ${COUNT} times")

# Report timestamp comparison without judgment
if(dependency_timestamp AND output_timestamp)
    if(output_timestamp STRGREATER dependency_timestamp)
        message(STATUS "Observation: Output file is NEWER than dependency file")
    else()
        message(STATUS "Observation: Output file is OLDER than dependency file")
    endif()
    
    if(execution_timestamp)
        message(STATUS "Observation: Command executed during build phase")
    else()
        message(STATUS "Observation: Command did not execute during build phase")
    endif()
else()
    message(FATAL_ERROR "TIMESTAMP DATA MISSING")
endif()

# Add success/failure message at the bottom
if(dependency_timestamp AND output_timestamp AND execution_timestamp)
    if(output_timestamp STRGREATER dependency_timestamp AND NOT execution_timestamp)
        message(STATUS "RESULT: Test PASSED - Command did not execute as expected")
        # Return success (0)
    else()
        message(STATUS "RESULT: Test FAILED - Command executed when it should not have")
        # Return failure (1)
        message(FATAL_ERROR "Test failed: Command executed unnecessarily")
    endif()
endif()
