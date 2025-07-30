cmake_minimum_required(VERSION 3.20)
project(OsAgnosticDependencyTest)

# Create paths
set(OUTPUT_FILE "${CMAKE_CURRENT_BINARY_DIR}/output.txt")
set(DEPENDENCY_FILE "${CMAKE_CURRENT_BINARY_DIR}/dependency.txt")
set(TIMESTAMP_FILE "${CMAKE_CURRENT_BINARY_DIR}/timestamps.txt")
set(COUNTER_FILE "${CMAKE_CURRENT_BINARY_DIR}/execution_counter.txt")

# Initialize counter to zero
file(WRITE "${COUNTER_FILE}" "0")
message(STATUS "CONFIGURE: Initialized counter to 0")

# Create DEPENDENCY file FIRST (so it exists before output)
file(WRITE "${DEPENDENCY_FILE}" "Dependency content created at configure time")
message(STATUS "CONFIGURE: Created dependency file: ${DEPENDENCY_FILE}")

# Record dependency file timestamp using cross-platform method
file(TIMESTAMP "${DEPENDENCY_FILE}" dependency_timestamp "%Y-%m-%d %H:%M:%S.%3N")
message(STATUS "CONFIGURE: Dependency file timestamp: ${dependency_timestamp}")
file(APPEND "${TIMESTAMP_FILE}" "DEPENDENCY: ${dependency_timestamp}\n")

# Wait 2 seconds to ensure timestamp difference
execute_process(
  COMMAND ${CMAKE_COMMAND} -E sleep 2
  RESULT_VARIABLE sleep_result
)
if(sleep_result)
  message(WARNING "Failed to sleep for timestamp precision")
endif()

# Create OUTPUT file SECOND (so it's newer than dependency)
file(WRITE "${OUTPUT_FILE}" "Output content created at configure time")
message(STATUS "CONFIGURE: Created output file: ${OUTPUT_FILE}")

# Record output file timestamp using cross-platform method
file(TIMESTAMP "${OUTPUT_FILE}" output_timestamp "%Y-%m-%d %H:%M:%S.%3N")
message(STATUS "CONFIGURE: Output file timestamp: ${output_timestamp}")
file(APPEND "${TIMESTAMP_FILE}" "OUTPUT: ${output_timestamp}\n")

# Add custom command that depends on the dependency file
add_custom_command(
  OUTPUT "${OUTPUT_FILE}"
  COMMAND ${CMAKE_COMMAND} -P "${CMAKE_CURRENT_SOURCE_DIR}/execute_command.cmake" "${COUNTER_FILE}" "${OUTPUT_FILE}" "${TIMESTAMP_FILE}"
  DEPENDS "${DEPENDENCY_FILE}"
  COMMENT "Custom command with dependency tracking"
)

# Create target that depends on the output
add_custom_target(test_target
  DEPENDS "${OUTPUT_FILE}"
  COMMAND ${CMAKE_COMMAND} -P "${CMAKE_CURRENT_SOURCE_DIR}/verify_results.cmake" "${COUNTER_FILE}" "${TIMESTAMP_FILE}"
)

# Add a test that builds the target
enable_testing()
add_test(
  NAME os_agnostic_dependency_test
  COMMAND ${CMAKE_COMMAND} --build ${CMAKE_CURRENT_BINARY_DIR} --target test_target
)
