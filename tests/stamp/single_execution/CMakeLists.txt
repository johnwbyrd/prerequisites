cmake_minimum_required(VERSION 3.20)
include(${PREREQUISITE_TEST_UTILS_DIR}/counter_file.cmake)

# Reset counter before test
init_counter_file(${CMAKE_CURRENT_BINARY_DIR}/outputs/counter.txt)

# Two-stamp architecture test
set(PRE_STAMP ${CMAKE_CURRENT_BINARY_DIR}/pre_stamp)
set(POST_STAMP ${CMAKE_CURRENT_BINARY_DIR}/post_stamp)

# Create pre-stamp dependency
add_custom_command(
  OUTPUT ${PRE_STAMP}
  COMMAND ${CMAKE_COMMAND} -E touch ${PRE_STAMP}
  COMMENT "Creating pre-stamp"
)

# Post-stamp with counter increment
add_custom_command(
  OUTPUT ${POST_STAMP}
  COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_SOURCE_DIR}/increment_counter.cmake
    ${CMAKE_CURRENT_BINARY_DIR}/outputs/counter.txt
  DEPENDS ${PRE_STAMP}
  COMMENT "Incrementing counter"
)

# Main target that depends on post-stamp
add_custom_target(test_target
  DEPENDS ${POST_STAMP}
)

# Verification target
add_custom_target(verify
  COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_SOURCE_DIR}/verify_counter.cmake
    ${CMAKE_CURRENT_BINARY_DIR}/outputs/counter.txt 1
  DEPENDS test_target
  COMMENT "Verifying counter value"
)

# Rebuild verification target
add_custom_target(rebuild_verify
  COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_SOURCE_DIR}/verify_counter.cmake
    ${CMAKE_CURRENT_BINARY_DIR}/outputs/counter.txt 1
  DEPENDS test_target
  COMMENT "Verifying counter value after rebuild"
)
