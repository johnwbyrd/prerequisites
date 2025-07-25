# Verify deferred mode variable substitution worked
if(NOT CMAKE_ARGC EQUAL 4)
    message(FATAL_ERROR "Usage: cmake -P verify_deferred.cmake <output_dir>")
endif()

set(OUTPUT_DIR "${CMAKE_ARGV3}")

# Check that output files exist
if(NOT EXISTS "${OUTPUT_DIR}/deferred_name.txt")
    message(FATAL_ERROR "DEFERRED SUBSTITUTION FAILURE: deferred_name.txt not created")
endif()

if(NOT EXISTS "${OUTPUT_DIR}/deferred_source.txt")
    message(FATAL_ERROR "DEFERRED SUBSTITUTION FAILURE: deferred_source.txt not created")
endif()

# Check file contents
file(READ "${OUTPUT_DIR}/deferred_name.txt" name_content)
string(STRIP "${name_content}" name_content)
if(NOT name_content STREQUAL "Deferred name: substitution_deferred")
    message(FATAL_ERROR "DEFERRED SUBSTITUTION FAILURE: Expected 'Deferred name: substitution_deferred', got '${name_content}'")
endif()

file(READ "${OUTPUT_DIR}/deferred_source.txt" source_content)
string(STRIP "${source_content}" source_content)
if(NOT source_content MATCHES "Deferred source: .*/substitution_deferred-prefix/src/substitution_deferred")
    message(FATAL_ERROR "DEFERRED SUBSTITUTION FAILURE: Source dir not substituted correctly: '${source_content}'")
endif()

message(STATUS "SUCCESS: Variable substitution working in deferred mode")