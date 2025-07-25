# Verify file dependency tracking works
if(NOT CMAKE_ARGC EQUAL 5)
    message(FATAL_ERROR "Usage: cmake -P verify_file_deps.cmake <output_dir> <source_dir>")
endif()

set(OUTPUT_DIR "${CMAKE_ARGV3}")
set(SOURCE_DIR "${CMAKE_ARGV4}")

# Check that outputs were created
set(REQUIRED_FILES
    "${OUTPUT_DIR}/build_output"
    "${OUTPUT_DIR}/install_output"
)

foreach(file ${REQUIRED_FILES})
    if(NOT EXISTS "${file}")
        message(FATAL_ERROR "FILE_DEPS FAILURE: Expected output ${file} not created!")
    endif()
    message(STATUS "PASS: ${file} exists")
endforeach()

# Check that source files exist and were tracked
set(SOURCE_FILES
    "${SOURCE_DIR}/source1.c"
    "${SOURCE_DIR}/source2.c" 
    "${SOURCE_DIR}/header.h"
)

foreach(file ${SOURCE_FILES})
    if(NOT EXISTS "${file}")
        message(FATAL_ERROR "FILE_DEPS FAILURE: Source file ${file} missing!")
    endif()
    message(STATUS "PASS: Source file ${file} exists")
endforeach()

message(STATUS "SUCCESS: File dependency tracking working correctly")