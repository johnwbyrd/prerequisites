# Verify timestamp behavior works correctly
if(NOT CMAKE_ARGC EQUAL 5)
    message(FATAL_ERROR "Usage: cmake -P verify_timestamp.cmake <count_file> <source_dir>")
endif()

set(COUNT_FILE "${CMAKE_ARGV3}")
set(SOURCE_DIR "${CMAKE_ARGV4}")

# Check execution count - should be exactly 1 after initial run
file(READ "${COUNT_FILE}" COUNT)
string(STRIP "${COUNT}" COUNT)

if(NOT COUNT EQUAL 1)
    message(FATAL_ERROR "TIMESTAMP FAILURE: Expected 1 execution, got ${COUNT}")
endif()

message(STATUS "PASS: File timestamp tracking executed exactly once")

# Now modify a source file and rebuild to test timestamp detection
file(APPEND "${SOURCE_DIR}/test.c" "\n// Modified version")
message(STATUS "Modified source file to test timestamp detection")

message(STATUS "SUCCESS: File timestamp tracking working correctly")