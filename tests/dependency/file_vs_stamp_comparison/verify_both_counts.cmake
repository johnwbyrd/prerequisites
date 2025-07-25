# Verify both execution counts
if(NOT CMAKE_ARGC EQUAL 8)
    message(FATAL_ERROR "Usage: cmake -P verify_both_counts.cmake <file_count_file> <stamp_count_file> <expected_file> <expected_stamp> <phase>")
endif()

set(FILE_COUNT_FILE "${CMAKE_ARGV3}")
set(STAMP_COUNT_FILE "${CMAKE_ARGV4}")
set(EXPECTED_FILE "${CMAKE_ARGV5}")
set(EXPECTED_STAMP "${CMAKE_ARGV6}")
set(PHASE "${CMAKE_ARGV7}")

# Read file-based count
if(EXISTS "${FILE_COUNT_FILE}")
    file(READ "${FILE_COUNT_FILE}" actual_file)
    string(STRIP "${actual_file}" actual_file)
else()
    set(actual_file 0)
endif()

# Read stamp-based count
if(EXISTS "${STAMP_COUNT_FILE}")
    file(READ "${STAMP_COUNT_FILE}" actual_stamp)
    string(STRIP "${actual_stamp}" actual_stamp)
else()
    set(actual_stamp 0)
endif()

# Verify file-based count
if(NOT actual_file EQUAL EXPECTED_FILE)
    message(FATAL_ERROR "FILE VS STAMP COMPARISON FAILURE (${PHASE}): File-based count is ${actual_file}, expected ${EXPECTED_FILE}")
endif()

# Verify stamp-based count
if(NOT actual_stamp EQUAL EXPECTED_STAMP)
    message(FATAL_ERROR "FILE VS STAMP COMPARISON FAILURE (${PHASE}): Stamp-based count is ${actual_stamp}, expected ${EXPECTED_STAMP}")
endif()

message(STATUS "PASS (${PHASE}): File-based = ${actual_file}, Stamp-based = ${actual_stamp}")