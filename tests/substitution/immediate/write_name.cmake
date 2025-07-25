# Write name with prefix to file
if(NOT CMAKE_ARGC EQUAL 5)
    message(FATAL_ERROR "Usage: cmake -P write_name.cmake <name> <output_file>")
endif()

set(NAME "${CMAKE_ARGV3}")
set(OUTPUT_FILE "${CMAKE_ARGV4}")

file(WRITE "${OUTPUT_FILE}" "Name: ${NAME}")