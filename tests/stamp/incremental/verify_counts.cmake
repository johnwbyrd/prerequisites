# Script to verify counter files have expected values
# Usage: cmake -P verify_counts.cmake <track_dir>

if(NOT CMAKE_ARGC EQUAL 4)
    message(FATAL_ERROR "Usage: cmake -P verify_counts.cmake <track_dir>")
endif()

set(TRACK_DIR "${CMAKE_ARGV3}")

# Check each counter file
foreach(step download build install)
    set(COUNTER_FILE "${TRACK_DIR}/${step}_count")
    
    if(NOT EXISTS "${COUNTER_FILE}")
        message(FATAL_ERROR "Counter file ${COUNTER_FILE} does not exist - step never executed")
    endif()
    
    file(READ "${COUNTER_FILE}" COUNT)
    string(STRIP "${COUNT}" COUNT)
    
    if(NOT COUNT MATCHES "^[0-9]+$")
        message(FATAL_ERROR "Invalid count '${COUNT}' in ${COUNTER_FILE}")
    endif()
    
    # For this test, we expect exactly 1 execution during configure time
    # Build-time should respect stamps and not re-execute
    if(NOT COUNT EQUAL 1)
        message(FATAL_ERROR "STAMP FAILURE: ${step} step executed ${COUNT} times, expected 1. Stamps not working!")
    endif()
    
    message(STATUS "PASS: ${step} step executed exactly once (count=${COUNT})")
endforeach()

message(STATUS "SUCCESS: All steps executed exactly once - stamps working correctly")