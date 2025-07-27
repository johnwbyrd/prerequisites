# Test Utilities for Prerequisites Test Suite
# Common functions used across multiple test files

# Function to initialize a counter file to zero with debugging
function(init_counter_file counter_file)
    file(WRITE "${counter_file}" "0")
    message(STATUS "COUNTER RESET: Initialized ${counter_file} to 0")
endfunction()

# Function to increment a counter file and report the new value
function(increment_counter_file counter_file)
    # Read current count
    if(EXISTS "${counter_file}")
        file(READ "${counter_file}" current_count)
        string(STRIP "${current_count}" current_count)
        if(NOT current_count MATCHES "^[0-9]+$")
            set(current_count 0)
        endif()
    else()
        set(current_count 0)
    endif()
    
    # Increment and write back
    math(EXPR new_count "${current_count} + 1")
    file(WRITE "${counter_file}" "${new_count}")
    
    message(STATUS "COUNTER INCREMENT: ${counter_file} incremented to ${new_count}")
endfunction()

# Function to verify a counter file contains the expected value
function(verify_counter_file counter_file expected_count description)
    if(NOT EXISTS "${counter_file}")
        message(FATAL_ERROR "COUNTER VERIFY FAILED: Counter file ${counter_file} does not exist - ${description}")
    endif()
    
    file(READ "${counter_file}" actual_count)
    string(STRIP "${actual_count}" actual_count)
    
    if(NOT actual_count MATCHES "^[0-9]+$")
        message(FATAL_ERROR "COUNTER VERIFY FAILED: Invalid count '${actual_count}' in ${counter_file} - ${description}")
    endif()
    
    if(NOT actual_count EQUAL expected_count)
        message(FATAL_ERROR "COUNTER VERIFY FAILED: ${description} - expected ${expected_count}, got ${actual_count} in ${counter_file}")
    endif()
    
    message(STATUS "COUNTER VERIFY PASSED: ${description} - count is ${actual_count} as expected")
endfunction()