# Write deferred source dir to file
if(NOT CMAKE_ARGC EQUAL 5)
    message(FATAL_ERROR "Usage: cmake -P write_deferred_source.cmake <source_dir> <output_file>")
endif()

set(SOURCE_DIR "${CMAKE_ARGV3}")
set(OUTPUT_FILE "${CMAKE_ARGV4}")

file(WRITE "${OUTPUT_FILE}" "Deferred source: ${SOURCE_DIR}")