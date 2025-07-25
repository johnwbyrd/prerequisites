# Verify that missing stamp caused rebuild
if(NOT CMAKE_ARGC EQUAL 4)
    message(FATAL_ERROR "Usage: cmake -P verify_rebuild.cmake <output_dir>")
endif()

set(OUTPUT_DIR "${CMAKE_ARGV3}")

# Check that outputs were recreated after stamp removal
set(REQUIRED_FILES
    "${OUTPUT_DIR}/download_output"
    "${OUTPUT_DIR}/build_output" 
    "${OUTPUT_DIR}/install_output"
)

foreach(file ${REQUIRED_FILES})
    if(NOT EXISTS "${file}")
        message(FATAL_ERROR "STAMP FAILURE: Missing stamp did not trigger rebuild - ${file} not recreated!")
    endif()
    message(STATUS "PASS: ${file} exists")
endforeach()

message(STATUS "SUCCESS: Missing stamp correctly triggered rebuild of dependent steps")