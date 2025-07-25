# Track executions across reconfigurations
if(NOT CMAKE_ARGC EQUAL 4)
    message(FATAL_ERROR "Usage: cmake -P track_execution.cmake <marker_file>")
endif()

set(MARKER_FILE "${CMAKE_ARGV3}")

# Read current count
if(EXISTS "${MARKER_FILE}")
    file(READ "${MARKER_FILE}" COUNT)
    string(STRIP "${COUNT}" COUNT)
    if(NOT COUNT MATCHES "^[0-9]+$")
        set(COUNT 0)
    endif()
else()
    set(COUNT 0)
endif()

# Increment
math(EXPR NEW_COUNT "${COUNT} + 1")
file(WRITE "${MARKER_FILE}" "${NEW_COUNT}")

message(STATUS "Execution tracked: ${NEW_COUNT}")

# If this runs more than once, stamps aren't working
if(NEW_COUNT GREATER 1)
    message(WARNING "POTENTIAL STAMP FAILURE: This is execution #${NEW_COUNT}")
endif()