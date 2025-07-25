cmake_minimum_required(VERSION 3.12)
project(Prerequisites LANGUAGES NONE)

# Add the cmake directory to the module path so users can find Prerequisite.cmake
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

# Always build and run tests - they validate the Prerequisites system
enable_testing()
add_subdirectory(tests)