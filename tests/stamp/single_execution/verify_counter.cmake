set(counter_file "${CMAKE_ARGV3}")
set(expected_value "${CMAKE_ARGV4}")

file(READ "${counter_file}" actual_value)
string(STRIP "${actual_value}" actual_value)

if(NOT actual_value STREQUAL expected_value)
  message(FATAL_ERROR
    "SINGLE EXECUTION TEST FAILED\n"
    "  Expected: ${expected_value}\n"
    "  Actual:   ${actual_value}\n"
    "  File:     ${counter_file}"
  )
endif()

message(STATUS "Counter verification passed: ${actual_value} == ${expected_value}")
