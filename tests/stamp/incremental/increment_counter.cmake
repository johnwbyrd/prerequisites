# Script to increment a counter file
# Usage: cmake -P increment_counter.cmake <counter_file>

if(NOT CMAKE_ARGC EQUAL 4)
    message(FATAL_ERROR "Usage: cmake -P increment_counter.cmake <counter_file>")
endif()

set(COUNTER_FILE "${CMAKE_ARGV3}")

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

message(STATUS "Counter ${COUNTER_FILE} incremented to ${NEW_COUNT}")