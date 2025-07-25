# CMake Prerequisites System
# Author: John Byrd, johnwbyrd at gmail dot com
#
# The prerequisites system lets you build external dependencies during CMake's 
# configuration phase, before the project() command runs. This is crucial when 
# you need to build the very tools that CMake is about to look for.

#[=======================================================================[.rst:
Prerequisite
------------

The prerequisites system lets you build external dependencies during CMake's
configuration phase, before the ``project()`` command runs. This is crucial
when you need to build the very tools that CMake is about to look for.

The prerequisites system breaks this deadlock. It can build your dependencies
immediately during configuration (so they're ready when ``project()`` runs), 
and it also creates normal CMake targets for incremental rebuilds later.

Functions
^^^^^^^^^

.. command:: Prerequisite_Add

  Main function to define a prerequisite.

  .. code-block:: cmake

    Prerequisite_Add(<name> [options...])

  **Note:** For all step command options (*_COMMAND), if no command is specified, 
  that step performs no action. Prerequisites are diverse external projects that 
  require explicit commands for each step. Command and argument options support 
  ``@VARIABLE@`` substitution using the variables listed below.

  **Options:**

  ``DEPENDS <prereqs...>``
    Names of other prerequisites that must be built first. The DEPENDS option 
    works differently at configure time versus build time. At configure time, 
    it does NOT enforce dependencies -- prerequisites execute in the order they 
    appear in your CMakeLists.txt regardless of DEPENDS declarations. At build 
    time, it creates proper target dependencies so this prerequisite's targets 
    depend on the dependency's targets. To ensure dependencies are built at 
    configure time, you must list prerequisites in dependency order in your 
    CMakeLists.txt.

  **Directory Options:**

  ``PREFIX <dir>``
    Root directory for this prerequisite

  ``SOURCE_DIR <dir>``
    Source directory (can be pre-existing)

  ``BINARY_DIR <dir>``
    Build directory

  ``INSTALL_DIR <dir>``
    Installation directory

  ``STAMP_DIR <dir>``
    Directory for stamp files

  ``LOG_DIR <dir>``
    Directory for log files (defaults to STAMP_DIR if not specified)

  **Download Step Options:**

  Git-based downloads:

  ``GIT_REPOSITORY <url>``
    Git repository URL

  ``GIT_TAG <tag>``
    Git branch, tag, or commit

  ``GIT_SHALLOW``
    Perform shallow clone

  URL-based downloads:

  ``URL <url>``
    Download URL for archives

  ``URL_HASH <algo>=<hash>``
    Hash verification

  Custom downloads:

  ``DOWNLOAD_COMMAND <cmd...>``
    Custom download command

  ``DOWNLOAD_NO_EXTRACT``
    Don't extract downloaded archives

  **Note:** Git-based and URL-based options are mutually exclusive.

  **Update Step Options:**

  ``UPDATE_COMMAND <cmd...>``
    Custom update command

  ``UPDATE_DISCONNECTED``
    Skip update step

  **Configure Step Options:**

  ``CONFIGURE_COMMAND <cmd...>``
    Configure command

  **Build Step Options:**

  ``BUILD_COMMAND <cmd...>``
    Build command

  ``BUILD_IN_SOURCE``
    Build in source directory

  **Install Step Options:**

  ``INSTALL_COMMAND <cmd...>``
    Install command

  **Test Step Options:**

  ``TEST_COMMAND <cmd...>``
    Test command

  **Command Variable Substitution:**

  All command arguments support ``@VARIABLE@`` substitution:

  * ``@PREREQUISITE_NAME@`` - The prerequisite name
  * ``@PREREQUISITE_PREFIX@`` - The prefix directory  
  * ``@PREREQUISITE_SOURCE_DIR@`` - Source directory path
  * ``@PREREQUISITE_BINARY_DIR@`` - Build directory path
  * ``@PREREQUISITE_INSTALL_DIR@`` - Install directory path
  * ``@PREREQUISITE_STAMP_DIR@`` - Stamp directory path
  * ``@PREREQUISITE_LOG_DIR@`` - Log directory path

  **Logging Options:**

  ``LOG_DOWNLOAD <bool>``
    When true, redirect download step output to log files instead of console

  ``LOG_UPDATE <bool>``
    When true, redirect update step output to log files instead of console

  ``LOG_CONFIGURE <bool>``
    When true, redirect configure step output to log files instead of console

  ``LOG_BUILD <bool>``
    When true, redirect build step output to log files instead of console

  ``LOG_INSTALL <bool>``
    When true, redirect install step output to log files instead of console

  ``LOG_TEST <bool>``
    When true, redirect test step output to log files instead of console

  ``LOG_OUTPUT_ON_FAILURE <bool>``
    When true, only show captured log output if the step fails

  **Normal behavior**: Step output appears directly in CMake configure log or 
  build output. **With LOG_* true**: Step output is captured to automatically 
  named files like ``<name>-build-out.log`` in LOG_DIR (or STAMP_DIR if LOG_DIR 
  not specified), console shows only summary messages.

  **File Dependency Options:**

  These options enable intelligent rebuild behavior by tracking changes to 
  specific files within a prerequisite's source tree, rather than relying 
  solely on timestamp-based stamp files.

  ``DOWNLOAD_DEPENDS <args...>``
    File dependency arguments for download step

  ``UPDATE_DEPENDS <args...>``
    File dependency arguments for update step

  ``CONFIGURE_DEPENDS <args...>``
    File dependency arguments for configure step

  ``BUILD_DEPENDS <args...>``
    File dependency arguments for build step

  ``INSTALL_DEPENDS <args...>``
    File dependency arguments for install step

  ``TEST_DEPENDS <args...>``
    File dependency arguments for test step

  **Purpose:** File dependency tracking allows prerequisites to rebuild only 
  when their internal dependencies have actually changed. This provides more 
  granular and efficient rebuild behavior than simple timestamp checking.

  **File Dependency Behavior:** When you specify file dependencies for a step, 
  you provide glob patterns that tell the system which files to track. The first 
  argument should typically be ``GLOB`` or ``GLOB_RECURSE``, followed by the 
  actual glob patterns with variable substitution applied. File dependencies 
  completely replace stamp-based tracking for that step -- the step will run 
  when any dependency file is newer than the step's outputs, or when outputs 
  are missing, using CMake's normal dependency resolution.

  **Control Options:**

  ``<STEP>_ALWAYS <bool>``
    Whether to always run specific step (e.g., ``CONFIGURE_ALWAYS``).  A true
    value forces the step to run every time, regardless of file dependencies.

.. command:: Prerequisite_Get_Property

  Retrieve properties from a prerequisite.

  .. code-block:: cmake

    Prerequisite_Get_Property(<name> <property> <output_variable>)

  **Properties:** All options from ``Prerequisite_Add`` can be retrieved as properties.

**Force Targets:**

  Force targets are automatically created for each step as ``<name>-force-<step>`` 
  (e.g., ``myprereq-force-build``). These targets remove the step's stamp file 
  and rebuild the step and all subsequent steps.

  .. code-block:: bash

    cmake --build . --target myprereq-force-build

#]=======================================================================]

# Implementation

# Internal prefix for all global properties and internal variables
# Can be changed in one place to avoid namespace collisions
set(_PREREQUISITE_PREFIX "_PREREQUISITE")

# Debug flag - set to TRUE to enable debug messages
set(_PREREQUISITE_DEBUG FALSE CACHE BOOL
    "Enable Prerequisites debug messages")

# Internal step list - defines the order and names of all prerequisite steps
set(_PREREQUISITE_STEPS DOWNLOAD UPDATE CONFIGURE BUILD INSTALL TEST)

# Internal substitution variables - defines all @PREREQUISITE_*@ variable names
set(_PREREQUISITE_SUBSTITUTION_VARS NAME PREFIX SOURCE_DIR BINARY_DIR
    INSTALL_DIR STAMP_DIR LOG_DIR)

# Debug message function - only prints when debugging is enabled
function(_Prerequisite_Debug message)
  if(_PREREQUISITE_DEBUG)
    message(STATUS "PREREQUISITE_DEBUG: ${message}")
  endif()
endfunction()

# Map each step to a new string by applying prefix and suffix
# Transforms each step in _PREREQUISITE_STEPS using the pattern:
# prefix + step + suffix
# Example: _Prerequisite_Map_Steps("LOG_" "" result) ->
#   LOG_DOWNLOAD, LOG_UPDATE, etc.
# Example: _Prerequisite_Map_Steps("" "_COMMAND" result) ->
#   DOWNLOAD_COMMAND, UPDATE_COMMAND, etc.
function(_Prerequisite_Map_Steps prefix suffix out_var)
  set(result "")
  foreach(step ${_PREREQUISITE_STEPS})
    list(APPEND result "${prefix}${step}${suffix}")
  endforeach()
  set(${out_var} ${result} PARENT_SCOPE)
endfunction()

# Debug function to dump all prerequisite properties for a given name
# WARNING: This function is for debugging purposes only
# Since CMake doesn't provide a way to enumerate custom global properties,
# this function checks all known prerequisite property names
function(_Prerequisite_Debug_Dump name)
  message(STATUS "=== Prerequisite Properties for ${name} ===")
  
  # Generate lists of all possible property names
  _Prerequisite_Map_Steps("" "_ALWAYS" step_always_opts)
  _Prerequisite_Map_Steps("LOG_" "" step_log_opts)
  _Prerequisite_Map_Steps("" "_COMMAND" step_command_opts)
  _Prerequisite_Map_Steps("" "_DEPENDS" step_depends_opts)
  
  # All possible property names
  set(all_properties
    # Directory properties
    PREFIX SOURCE_DIR BINARY_DIR INSTALL_DIR STAMP_DIR LOG_DIR
    # Git/URL properties  
    GIT_REPOSITORY GIT_TAG URL URL_HASH
    # Boolean flags
    GIT_SHALLOW DOWNLOAD_NO_EXTRACT UPDATE_DISCONNECTED BUILD_IN_SOURCE
    # Other options
    LOG_OUTPUT_ON_FAILURE DEPENDS
    # Generated step-specific properties
    ${step_always_opts} ${step_log_opts} ${step_command_opts} ${step_depends_opts}
  )
  
  # Check each property and display if set
  foreach(prop ${all_properties})
    get_property(value GLOBAL PROPERTY ${_PREREQUISITE_PREFIX}_${name}_${prop})
    get_property(is_set GLOBAL PROPERTY ${_PREREQUISITE_PREFIX}_${name}_${prop} SET)
    if(is_set)
      message(STATUS "  ${prop} = ${value}")
    endif()
  endforeach()
  
  message(STATUS "=== End Properties for ${name} ===")
endfunction()

# Determine if we're running at configure time (before project()) vs build time
# (after project())
#
# This function solves a critical problem in the prerequisites system:
# distinguishing between configure-time execution (when prerequisites should run
# immediately) and build-time execution (when prerequisites should create CMake
# targets for later execution).
#
# The prerequisites system needs to support dual execution modes:
# 1. CONFIGURE TIME: When Prerequisite_Add() is called BEFORE project(),
#    prerequisites must execute immediately to bootstrap tools (like compilers)
#    that project() will need.
# 2. BUILD TIME: When Prerequisite_Add() is called AFTER project(),
#    prerequisites should create normal CMake targets that execute during the
#    build phase.
#
# THE DETECTION APPROACH:
# The function uses a two-stage check to handle both standalone and nested
# CMake contexts:
#
# 1. First, check if CMAKE_PROJECT_NAME is empty - this handles the common case
#    where no project() has been called in the current execution context.
#
# 2. Second, for nested contexts (like CTest), check if CMAKE_SOURCE_DIR differs
#    from CMAKE_CURRENT_SOURCE_DIR - this indicates we're in a subdirectory
#    that hasn't called project() yet, even if a parent process has.
#
# EXECUTION SCENARIOS:
#
# Scenario 1: Standalone CMake execution
#   cmake_minimum_required(VERSION 3.25)
#   Prerequisite_Add(my_prereq ...)  # <- CMAKE_PROJECT_NAME="" -> CONFIGURE
#   project(MyProject)                # <- Sets CMAKE_PROJECT_NAME
#   Prerequisite_Add(my_prereq2 ...)  # <- CMAKE_PROJECT_NAME set -> BUILD TIME
#
# Scenario 2: CTest execution (nested context)
#   Parent process: project(TestRunner) -> sets CMAKE_PROJECT_NAME="TestRunner"
#   Child process spawned by CTest:
#     cmake_minimum_required(VERSION 3.25)
#     # CMAKE_PROJECT_NAME="" (child process starts with empty project name)
#     # CMAKE_SOURCE_DIR != CMAKE_CURRENT_SOURCE_DIR (different directories)
#     Prerequisite_Add(test_prereq ...) # <- Either condition -> CONFIGURE TIME
#     project(MyTest)                   # <- Sets CMAKE_PROJECT_NAME for context
#     Prerequisite_Add(test_prereq2 ...) # <- Same directory -> BUILD TIME
#
# This approach correctly handles both standalone CMake execution and nested
# contexts like testing frameworks, ensuring prerequisites run immediately
# when needed for bootstrapping and defer to build-time targets otherwise.
#
# Returns TRUE if no project() has been called in the current context
# (configure time)
# Returns FALSE if project() has been called in the current context
# (build time)
function(_Prerequisite_Is_Configure_Time out_var)
  _Prerequisite_Debug("_Prerequisite_Is_Configure_Time: CMAKE_PROJECT_NAME='${CMAKE_PROJECT_NAME}' CMAKE_SOURCE_DIR='${CMAKE_SOURCE_DIR}' CMAKE_CURRENT_SOURCE_DIR='${CMAKE_CURRENT_SOURCE_DIR}'")
  
  # Check if CMAKE_PROJECT_NAME is set - this indicates project() has been
  # called in this context. In nested contexts, we need to check if the
  # current source directory is the same as the top-level source directory.
  if(NOT CMAKE_PROJECT_NAME OR CMAKE_PROJECT_NAME STREQUAL "")
    _Prerequisite_Debug("  -> returning TRUE (configure time: no project() called - CMAKE_PROJECT_NAME empty)")
    set(${out_var} TRUE PARENT_SCOPE)
  elseif(NOT "${CMAKE_SOURCE_DIR}" STREQUAL "${CMAKE_CURRENT_SOURCE_DIR}")
    _Prerequisite_Debug("  -> returning TRUE (configure time: CMAKE_SOURCE_DIR != CMAKE_CURRENT_SOURCE_DIR)")
    set(${out_var} TRUE PARENT_SCOPE)
  else()
    _Prerequisite_Debug("  -> returning FALSE (build time: project() called in this directory)")
    set(${out_var} FALSE PARENT_SCOPE)
  endif()
endfunction()

# Parse all arguments using cmake_parse_arguments
# - Extract options like IMMEDIATE, BUILD_ALWAYS
# - Extract single-value args like PREFIX, SOURCE_DIR, etc.
# - Extract multi-value args like DEPENDS, COMMANDS, and all step-specific
#   options
# - Store all parsed arguments as global properties using pattern:
#   ${_PREREQUISITE_PREFIX}_${name}_${property_name}
# - This allows other helper functions to retrieve arguments using
#   get_property(GLOBAL) without needing PARENT_SCOPE variable passing
# - Follows the same approach as ExternalProject and FetchContent
function(_Prerequisite_Parse_Arguments name)
  # Generate step-specific argument names
  _Prerequisite_Map_Steps("" "_ALWAYS" step_always_opts)
  _Prerequisite_Map_Steps("LOG_" "" step_log_opts)
  _Prerequisite_Map_Steps("" "_COMMAND" step_command_opts)
  _Prerequisite_Map_Steps("" "_DEPENDS" step_depends_opts)
  
  # Set up argument categories for cmake_parse_arguments
  set(options
    GIT_SHALLOW DOWNLOAD_NO_EXTRACT UPDATE_DISCONNECTED BUILD_IN_SOURCE
  )
  
  set(oneValueArgs
    PREFIX SOURCE_DIR BINARY_DIR INSTALL_DIR STAMP_DIR LOG_DIR
    GIT_REPOSITORY GIT_TAG URL URL_HASH LOG_OUTPUT_ON_FAILURE
    ${step_log_opts}
    ${step_always_opts}
  )
  
  set(multiValueArgs
    DEPENDS
    ${step_command_opts}
    ${step_depends_opts}
  )
  
  # Parse arguments starting from index 1 (skip the name parameter)
  cmake_parse_arguments(PARSE_ARGV 1 PA "${options}" "${oneValueArgs}"
      "${multiValueArgs}")
  
  # Store each parsed argument as a global property
  foreach(option ${options})
    if(PA_${option})
      set_property(GLOBAL PROPERTY ${_PREREQUISITE_PREFIX}_${name}_${option}
          TRUE)
    endif()
  endforeach()
  
  foreach(arg ${oneValueArgs})
    if(DEFINED PA_${arg})
      set_property(GLOBAL PROPERTY ${_PREREQUISITE_PREFIX}_${name}_${arg}
          "${PA_${arg}}")
    endif()
  endforeach()
  
  foreach(arg ${multiValueArgs})
    if(DEFINED PA_${arg})
      set_property(GLOBAL PROPERTY ${_PREREQUISITE_PREFIX}_${name}_${arg}
          "${PA_${arg}}")
    endif()
  endforeach()
  
  # Validate argument combinations
  get_property(has_git GLOBAL PROPERTY
      ${_PREREQUISITE_PREFIX}_${name}_GIT_REPOSITORY SET)
  get_property(has_url GLOBAL PROPERTY
      ${_PREREQUISITE_PREFIX}_${name}_URL SET)
  if(has_git AND has_url)
    message(FATAL_ERROR
        "Prerequisite ${name}: GIT_REPOSITORY and URL are mutually exclusive")
  endif()
endfunction()

# Set up default directory structure if not explicitly provided
# - Default PREFIX based on name
# - Default SOURCE_DIR, BINARY_DIR, STAMP_DIR, etc. based on PREFIX
function(_Prerequisite_Setup_Directories name)
  # Set up directory defaults - skip NAME since it's not a directory
  set(directory_vars PREFIX SOURCE_DIR BINARY_DIR INSTALL_DIR STAMP_DIR
      LOG_DIR)
  
  # First pass: compute defaults
  foreach(var ${directory_vars})
    get_property(user_value GLOBAL PROPERTY
        ${_PREREQUISITE_PREFIX}_${name}_${var})
    
    if(user_value)
      set(${var} "${user_value}")
    else()
      # Compute defaults based on variable type
      if(var STREQUAL "PREFIX")
        set(${var} "${CMAKE_CURRENT_BINARY_DIR}/${name}-prefix")
      elseif(var STREQUAL "SOURCE_DIR")
        set(${var} "${PREFIX}/src/${name}")
      elseif(var STREQUAL "BINARY_DIR")
        set(${var} "${PREFIX}/src/${name}-build")
      elseif(var STREQUAL "INSTALL_DIR")
        set(${var} "${PREFIX}")
      elseif(var STREQUAL "STAMP_DIR")
        set(${var} "${PREFIX}/src/${name}-stamp")
      elseif(var STREQUAL "LOG_DIR")
        set(${var} "${STAMP_DIR}")
      endif()
    endif()
  endforeach()
  
  # Second pass: store final values and create directories
  foreach(var ${directory_vars})
    set_property(GLOBAL PROPERTY ${_PREREQUISITE_PREFIX}_${name}_${var}
        "${${var}}")
    file(MAKE_DIRECTORY "${${var}}")
  endforeach()
endfunction()

# Substitute @PREREQUISITE_*@ variables in command arguments
# Requires the substitution variables to be set in parent scope
function(_Prerequisite_Substitute_Variables input_list out_var)
  set(result "")
  foreach(item ${input_list})
    set(substituted "${item}")
    foreach(var ${_PREREQUISITE_SUBSTITUTION_VARS})
      if(DEFINED ${var})
        string(REPLACE "@PREREQUISITE_${var}@" "${${var}}" substituted
            "${substituted}")
      endif()
    endforeach()
    list(APPEND result "${substituted}")
  endforeach()
  set(${out_var} "${result}" PARENT_SCOPE)
endfunction()

# Resolve file dependencies for a step using glob patterns
function(_Prerequisite_Resolve_File_Dependencies patterns out_files
    out_uses_file_deps)
  set(resolved_files "")
  set(uses_file_deps FALSE)
  
  if(NOT patterns)
    set(${out_files} "" PARENT_SCOPE)
    set(${out_uses_file_deps} FALSE PARENT_SCOPE)
    return()
  endif()
  
  set(uses_file_deps TRUE)
  
  # Process GLOB/GLOB_RECURSE patterns
  set(glob_mode "")
  set(current_patterns "")
  
  foreach(arg ${patterns})
    if(arg STREQUAL "GLOB" OR arg STREQUAL "GLOB_RECURSE")
      # Process any accumulated patterns with previous mode
      if(glob_mode AND current_patterns)
        if(glob_mode STREQUAL "GLOB")
          file(GLOB pattern_files ${current_patterns})
        else()
          file(GLOB_RECURSE pattern_files ${current_patterns})
        endif()
        list(APPEND resolved_files ${pattern_files})
      endif()
      # Start new glob mode
      set(glob_mode "${arg}")
      set(current_patterns "")
    else()
      # Accumulate patterns for current mode
      list(APPEND current_patterns "${arg}")
    endif()
  endforeach()
  
  # Process final batch of patterns
  if(glob_mode AND current_patterns)
    if(glob_mode STREQUAL "GLOB")
      file(GLOB pattern_files ${current_patterns})
    else()
      file(GLOB_RECURSE pattern_files ${current_patterns})
    endif()
    list(APPEND resolved_files ${pattern_files})
  endif()
  
  set(${out_files} "${resolved_files}" PARENT_SCOPE)
  set(${out_uses_file_deps} "${uses_file_deps}" PARENT_SCOPE)
endfunction()

# Execute a step immediately during configure time
function(_Prerequisite_Execute_Immediate name step command working_dir
    stamp_file)
  _Prerequisite_Substitute_Variables("${command}" substituted_command)
  
  message(STATUS "Prerequisite ${name}: Running ${step} step immediately")
  execute_process(
    COMMAND ${substituted_command}
    WORKING_DIRECTORY "${working_dir}"
    RESULT_VARIABLE result
  )
  
  if(NOT result EQUAL 0)
    # Clean up stamps for this and subsequent steps
    foreach(cleanup_step ${_PREREQUISITE_STEPS})
      get_property(stamp_dir GLOBAL PROPERTY
          ${_PREREQUISITE_PREFIX}_${name}_STAMP_DIR)
      file(REMOVE "${stamp_dir}/${name}-${cleanup_step}")
      if(cleanup_step STREQUAL step)
        break()
      endif()
    endforeach()
    message(FATAL_ERROR "Prerequisite ${name}: ${step} step failed")
  endif()
  
  # Create stamp file
  file(TOUCH "${stamp_file}")
endfunction()

# Create build-time target for a step
function(_Prerequisite_Create_Build_Target name step command working_dir stamp_file dependencies)
  string(TOLOWER "${step}" step_lower)
  
  # Substitute variables in command for build-time execution
  _Prerequisite_Substitute_Variables("${command}" substituted_command)
  
  # Create the custom command that produces a stamp file
  add_custom_command(
    OUTPUT "${stamp_file}"
    COMMAND ${substituted_command}
    COMMAND ${CMAKE_COMMAND} -E touch "${stamp_file}"
    DEPENDS ${dependencies}
    WORKING_DIRECTORY "${working_dir}"
    COMMENT "Prerequisite ${name}: Running ${step} step"
  )
  
  # Create named target that depends on the stamp file
  add_custom_target(${name}-${step_lower}
    DEPENDS "${stamp_file}"
  )
  
  # Create force target (always removes stamp then runs)
  add_custom_target(${name}-force-${step_lower}
    COMMAND ${CMAKE_COMMAND} -E remove "${stamp_file}"
    COMMAND ${CMAKE_COMMAND} --build ${CMAKE_BINARY_DIR} --target ${name}-${step_lower}
    COMMENT "Prerequisite ${name}: Force ${step} step"
  )
endfunction()

# Process a single prerequisite step
function(_Prerequisite_Process_Single_Step name step is_configure_time previous_stamp_file out_stamp_file)
  # Get step command
  get_property(step_command GLOBAL PROPERTY ${_PREREQUISITE_PREFIX}_${name}_${step}_COMMAND)
  _Prerequisite_Debug("_Prerequisite_Process_Single_Step(${name}, ${step}) - step_command='${step_command}'")
  if(NOT step_command)
    _Prerequisite_Debug("  No command for ${step} step, skipping")
    set(${out_stamp_file} "${previous_stamp_file}" PARENT_SCOPE)
    return()
  endif()
  
  # Get directories
  get_property(STAMP_DIR GLOBAL PROPERTY ${_PREREQUISITE_PREFIX}_${name}_STAMP_DIR)
  get_property(BINARY_DIR GLOBAL PROPERTY ${_PREREQUISITE_PREFIX}_${name}_BINARY_DIR)
  
  # Set up stamp file path
  set(stamp_file "${STAMP_DIR}/${name}-${step}")
  
  # Process file dependencies
  get_property(step_depends GLOBAL PROPERTY ${_PREREQUISITE_PREFIX}_${name}_${step}_DEPENDS)
  if(step_depends)
    # Substitute variables in patterns
    _Prerequisite_Substitute_Variables("${step_depends}" expanded_patterns)
    # Resolve file patterns
    _Prerequisite_Resolve_File_Dependencies("${expanded_patterns}" resolved_files uses_file_deps)
    
    if(uses_file_deps AND NOT resolved_files)
      message(FATAL_ERROR "Prerequisite ${name}: ${step}_DEPENDS patterns matched no files: ${expanded_patterns}")
    endif()
  else()
    set(resolved_files "")
    set(uses_file_deps FALSE)
  endif()
  
  # Immediate execution if at configure time
  if(is_configure_time)
    _Prerequisite_Debug("  ${step} step: configure-time execution, checking if needs to run")
    set(needs_to_run FALSE)
    
    if(uses_file_deps)
      # Compare file timestamps with stamp file
      _Prerequisite_Debug("  Using file dependencies: ${resolved_files}")
      if(NOT EXISTS "${stamp_file}")
        _Prerequisite_Debug("  Stamp file missing: ${stamp_file}")
        set(needs_to_run TRUE)
      else()
        # Check if any dependency files are newer than stamp
        foreach(dep_file ${resolved_files})
          if(EXISTS "${dep_file}" AND "${dep_file}" IS_NEWER_THAN "${stamp_file}")
            _Prerequisite_Debug("  Dependency file newer: ${dep_file}")
            set(needs_to_run TRUE)
            break()
          endif()
        endforeach()
      endif()
    else()
      # Check if stamp file exists
      _Prerequisite_Debug("  Using stamp-only dependencies")
      if(NOT EXISTS "${stamp_file}")
        _Prerequisite_Debug("  Stamp file missing: ${stamp_file}")
        set(needs_to_run TRUE)
      endif()
    endif()
    
    _Prerequisite_Debug("  needs_to_run=${needs_to_run}")
    if(needs_to_run)
      _Prerequisite_Execute_Immediate(${name} ${step} "${step_command}" "${BINARY_DIR}" "${stamp_file}")
    endif()
  else()
    _Prerequisite_Debug("  ${step} step: build-time only")
  endif()
  
  # Create build-time targets
  set(step_deps "")
  if(previous_stamp_file)
    list(APPEND step_deps "${previous_stamp_file}")
  endif()
  if(uses_file_deps)
    list(APPEND step_deps ${resolved_files})
  endif()
  
  _Prerequisite_Create_Build_Target(${name} ${step} "${step_command}" "${BINARY_DIR}" "${stamp_file}" "${step_deps}")
  
  # Return the stamp file for next iteration
  set(${out_stamp_file} "${stamp_file}" PARENT_SCOPE)
endfunction()

# Process each step in order (DOWNLOAD, UPDATE, CONFIGURE, BUILD, INSTALL, TEST)
function(_Prerequisite_Process_Steps name)
  # Retrieve configure-time flag
  get_property(is_configure_time GLOBAL PROPERTY ${_PREREQUISITE_PREFIX}_${name}_IS_CONFIGURE_TIME)
  _Prerequisite_Debug("_Prerequisite_Process_Steps(${name}) - is_configure_time=${is_configure_time}")
  
  # Set up variables for substitution (needed by helper functions)
  foreach(var ${_PREREQUISITE_SUBSTITUTION_VARS})
    if(var STREQUAL "NAME")
      set(${var} "${name}")
    else()
      get_property(${var} GLOBAL PROPERTY ${_PREREQUISITE_PREFIX}_${name}_${var})
    endif()
  endforeach()
  
  # Process each step
  set(previous_stamp_file "")
  foreach(step ${_PREREQUISITE_STEPS})
    _Prerequisite_Process_Single_Step(${name} ${step} ${is_configure_time} "${previous_stamp_file}" stamp_file)
    set(previous_stamp_file "${stamp_file}")
  endforeach()
  
  # Handle prerequisite-level dependencies
  get_property(prerequisite_depends GLOBAL PROPERTY ${_PREREQUISITE_PREFIX}_${name}_DEPENDS)
  if(prerequisite_depends)
    foreach(dep_prereq ${prerequisite_depends})
      foreach(step ${_PREREQUISITE_STEPS})
        get_property(step_command GLOBAL PROPERTY ${_PREREQUISITE_PREFIX}_${name}_${step}_COMMAND)
        if(step_command)
          string(TOLOWER "${step}" step_lower)
          add_dependencies(${name}-${step_lower} ${dep_prereq}-${step_lower})
        endif()
      endforeach()
    endforeach()
  endif()
endfunction()

function(Prerequisite_Add name)
  _Prerequisite_Is_Configure_Time(is_configure_time)
  _Prerequisite_Debug("Prerequisite_Add(${name}) - is_configure_time=${is_configure_time}")
  set_property(GLOBAL PROPERTY ${_PREREQUISITE_PREFIX}_${name}_IS_CONFIGURE_TIME "${is_configure_time}")
  _Prerequisite_Parse_Arguments(${name} ${ARGN})
  _Prerequisite_Setup_Directories(${name})
  _Prerequisite_Process_Steps(${name})
  
  _Prerequisite_Debug("Prerequisite_Add(${name}) - processing complete")
endfunction()

function(Prerequisite_Get_Property name property output_variable)
  # Retrieve properties from a prerequisite
  # - Uses global properties stored with pattern ${_PREREQUISITE_PREFIX}_${name}_${property_name}
  # - This matches the storage approach used by _Prerequisite_Parse_Arguments
  # - Follows the same design as ExternalProject_Get_Property and FetchContent
  # - All options from Prerequisite_Add can be retrieved this way
  get_property(value GLOBAL PROPERTY ${_PREREQUISITE_PREFIX}_${name}_${property})
  set(${output_variable} "${value}" PARENT_SCOPE)
endfunction()