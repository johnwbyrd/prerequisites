# Write binary dir with prefix to file
if(NOT CMAKE_ARGC EQUAL 5)
    message(FATAL_ERROR "Usage: cmake -P write_binary_dir.cmake <binary_dir> <output_file>")
endif()

set(BINARY_DIR "${CMAKE_ARGV3}")
set(OUTPUT_FILE "${CMAKE_ARGV4}")

file(WRITE "${OUTPUT_FILE}" "Binary dir: ${BINARY_DIR}")