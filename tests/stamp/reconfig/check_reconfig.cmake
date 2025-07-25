# Check that reconfiguration didn't cause re-execution
if(NOT CMAKE_ARGC EQUAL 4)
    message(FATAL_ERROR "Usage: cmake -P check_reconfig.cmake <marker_file>")
endif()

set(MARKER_FILE "${CMAKE_ARGV3}")

if(NOT EXISTS "${MARKER_FILE}")
    message(FATAL_ERROR "Marker file ${MARKER_FILE} missing - prerequisite never executed")
endif()

file(READ "${MARKER_FILE}" COUNT)
string(STRIP "${COUNT}" COUNT)

message(STATUS "Total executions recorded: ${COUNT}")

# This test script is only run after a reconfiguration
# So if count > 1, it means stamps didn't prevent re-execution
if(COUNT GREATER 1)
    message(FATAL_ERROR "STAMP FAILURE: Prerequisite executed ${COUNT} times across reconfigurations. Stamps not working!")
else()
    message(STATUS "SUCCESS: Prerequisite executed only once despite reconfiguration - stamps working")
endif()