# Verify execution count
if(NOT CMAKE_ARGC EQUAL 6)
    message(FATAL_ERROR "Usage: cmake -P verify_count.cmake <count_file> <expected> <phase>")
endif()

set(COUNT_FILE "${CMAKE_ARGV3}")
set(EXPECTED "${CMAKE_ARGV4}")
set(PHASE "${CMAKE_ARGV5}")

# Read actual count
if(EXISTS "${COUNT_FILE}")
    file(READ "${COUNT_FILE}" actual)
    string(STRIP "${actual}" actual)
else()
    set(actual 0)
endif()

if(NOT actual EQUAL EXPECTED)
    message(FATAL_ERROR "BASIC FILE BEHAVIOR FAILURE (${PHASE}): Expected ${EXPECTED} executions, got ${actual}")
endif()

message(STATUS "PASS (${PHASE}): Execution count = ${actual}")