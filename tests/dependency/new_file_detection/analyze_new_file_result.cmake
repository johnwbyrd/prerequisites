# Analyze new file detection result
if(NOT CMAKE_ARGC EQUAL 4)
    message(FATAL_ERROR "Usage: cmake -P analyze_new_file_result.cmake <count_file>")
endif()

set(COUNT_FILE "${CMAKE_ARGV3}")

# Read actual count
if(EXISTS "${COUNT_FILE}")
    file(READ "${COUNT_FILE}" actual)
    string(STRIP "${actual}" actual)
else()
    set(actual 0)
endif()

if(actual EQUAL 1)
    message(STATUS "RESULT: New file was NOT detected (count still 1)")
    message(STATUS "CONCLUSION: File globs are resolved at configure time, not build time")
    message(STATUS "IMPLICATION: New files require reconfiguration to be detected")
elseif(actual EQUAL 2)
    message(STATUS "RESULT: New file WAS detected (count increased to 2)")
    message(STATUS "CONCLUSION: File globs are dynamically resolved at build time")
    message(STATUS "IMPLICATION: New files are automatically detected without reconfiguration")
else()
    message(FATAL_ERROR "UNEXPECTED RESULT: Count is ${actual}, expected 1 or 2")
endif()

message(STATUS "NEW FILE DETECTION ANALYSIS COMPLETE")