# Increment execution counter
if(NOT CMAKE_ARGC EQUAL 4)
    message(FATAL_ERROR "Usage: cmake -P increment_and_check.cmake <count_file>")
endif()

set(COUNT_FILE "${CMAKE_ARGV3}")

# Read current count
if(EXISTS "${COUNT_FILE}")
    file(READ "${COUNT_FILE}" COUNT)
    string(STRIP "${COUNT}" COUNT)
    if(NOT COUNT MATCHES "^[0-9]+$")
        set(COUNT 0)
    endif()
else()
    set(COUNT 0)
endif()

# Increment
math(EXPR NEW_COUNT "${COUNT} + 1")
file(WRITE "${COUNT_FILE}" "${NEW_COUNT}")

message(STATUS "File timestamp test execution #${NEW_COUNT}")