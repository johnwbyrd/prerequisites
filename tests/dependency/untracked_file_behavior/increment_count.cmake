# Increment execution counter
if(NOT CMAKE_ARGC EQUAL 4)
    message(FATAL_ERROR "Usage: cmake -P increment_count.cmake <count_file>")
endif()

set(COUNT_FILE "${CMAKE_ARGV3}")

# Read current count
if(EXISTS "${COUNT_FILE}")
    file(READ "${COUNT_FILE}" current_count)
    string(STRIP "${current_count}" current_count)
    if(NOT current_count MATCHES "^[0-9]+$")
        set(current_count 0)
    endif()
else()
    set(current_count 0)
endif()

# Increment and write back
math(EXPR new_count "${current_count} + 1")
file(WRITE "${COUNT_FILE}" "${new_count}")

message(STATUS "Untracked file behavior build executed (count: ${new_count})")