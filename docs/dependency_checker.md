# Prerequisites Unified Dependency Checker Design (Final)

## Problem Statement

The current Prerequisites system experiences double-execution issues on Windows with the Visual Studio generator. This occurs because CMake's dependency system sometimes triggers custom commands even when they've already been executed during configuration. The root cause is inconsistent behavior between configure-time and build-time execution paths.

## Final Solution

Implement a unified dependency checker that:
1. Works identically during configure-time (via `execute_process()`) and build-time (via `add_custom_command()`)
2. Verifies dependencies before executing commands
3. Creates a single stamp file on success
4. Removes stamp file on failure
5. Integrates with existing logging system
6. Properly handles command arguments across platforms
7. Provides visibility into command execution progress

## Architecture Overview

The dependency checker consists of:
- A CMake script (`prerequisite_dependency_checker.cmake`) that handles the core logic
- A dependency list file (one path per line)
- A command list file (CMake list format, one command per line)
- A single stamp file marking successful completion

```
prerequisite-wrappers/
└── <name>/
    ├── <step>-deps.txt       # Dependency list (one file per line)
    ├── <step>-commands.txt   # Command list (CMake list format)
    └── <step>-checker.cmake  # Unified dependency checker
```

## File Formats

### Dependency List File
- Plain text file with one dependency path per line
- Paths are absolute or relative to build directory
- Empty file means no dependencies (command always runs)
- Example:
  ```
  C:/git/prerequisites/build/stamps/prereq-download-pre
  C:/git/prerequisites/source/file1.txt
  C:/git/prerequisites/source/file2.txt
  ```

### Command List File
- Contains commands in CMake list format (one command per line)
- Each line is a complete command with arguments separated by semicolons
- Variable substitution happens when writing this file (not during execution)
- Example:
  ```
  cmake;-S;@PREREQUISITE_SOURCE_DIR@;-B;@PREREQUISITE_BINARY_DIR@
  cmake;--build;@PREREQUISITE_BINARY_DIR@;--target;install
  ```

### Stamp File
- Empty file created on successful command execution
- Path: `${STAMP_DIR}/${name}-${step}-stamp`
- Contains no content, only timestamp matters

## Execution Flow

1. **Check if stamp file exists**
   - If not, command needs to run (proceed to step 3)
   - If yes, continue to step 2

2. **Verify dependencies**
   - For each dependency in deps file:
     - If dependency is newer than stamp file, command needs to run
     - If dependency doesn't exist, fail with error
   - If all dependencies are older than stamp file, exit successfully

3. **Execute commands**
   - For each command in command list:
     - Parse into proper arguments based on platform
     - Execute with correct working directory
     - Capture output based on logging settings
     - Provide progress feedback to user
   - On success, create stamp file
   - On failure, remove stamp file and propagate error

## Detailed Implementation

### Platform-Aware Command Parsing

The key improvement over checker_design_2.md is platform-specific command parsing:

PSEUDOCODE:
```
FUNCTION parse_command(line, platform):
    IF platform is Windows:
        # Windows requires special handling for command parsing
        Replace all semicolons with spaces in the command string
        Return the resulting string as the command
    ELSE:
        # UNIX-style command parsing
        Parse the command string into separate arguments using standard UNIX rules
        Return the parsed command arguments
    END IF
```

This addresses the Windows command parsing limitation by:
- Using string replacement for Windows to preserve command structure
- Maintaining UNIX-style parsing for non-Windows platforms
- Ensuring proper handling of Windows-specific command patterns

### Enhanced Logging Implementation

Improved logging addresses the visibility gap:

PSEUDOCODE:
```
FUNCTION setup_logging(log_file, log_output_on_failure):
    IF log_file is specified AND log_output_on_failure is true:
        # Only capture output, don't suppress console output
        Configure logging to write to log_file
        Set up to show command output in console
        RETURN logging configuration
    ELSE IF log_file is specified:
        # Capture output and suppress console output
        Configure logging to write to log_file
        Set up to suppress command output in console
        RETURN logging configuration
    ELSE:
        # No logging needed
        RETURN empty logging configuration
    END IF

FUNCTION execute_command(command, working_directory, logging_config):
    Display "Running prerequisite command: [command]"
    Execute the command in the specified working directory
    Apply the logging configuration
    Capture the result code
    RETURN result code
```

This implementation:
- Honors LOG_OUTPUT_ON_FAILURE to control output visibility
- Always shows command being executed for progress feedback
- Captures full output to log files when requested
- Provides better user experience during long-running commands

### Partial Command Execution Tracking

Added tracking for multi-command steps:

PSEUDOCODE:
```
FUNCTION execute_commands(command_lines, platform, working_directory, logging_config):
    Initialize empty list: successful_commands
    
    FOR EACH line IN command_lines:
        command = parse_command(line, platform)
        Display "Running prerequisite command: [command]"
        
        result = execute_command(command, working_directory, logging_config)
        
        IF result is not successful:
            IF successful_commands is not empty:
                Display "Prerequisite step failed after [count] successful commands"
                Log which commands succeeded before failure
            END IF
            Remove stamp file
            IF log_file exists:
                Display contents of log_file
            END IF
            RETURN error
        END IF
        
        Add line to successful_commands
    END FOR
    
    Create stamp file
    RETURN success
```

This addresses the partial command execution concern by:
- Tracking which commands succeeded before a failure
- Providing clear feedback about progress when failures occur
- Making it easier to diagnose issues in multi-command steps

## Integration with Prerequisites System

### Configure-Time Execution

PSEUDOCODE:
```
FUNCTION execute_dependency_checker_configure_time(name, step, binary_dir, log_dir, debug):
    deps_file = get_dependency_file_path(name, step)
    command_file = get_command_file_path(name, step)
    stamp_file = get_stamp_file_path(name, step)
    log_file = get_log_file_path(name, step, log_dir)
    
    checker_script = get_checker_script_path()
    
    Execute the dependency checker script with parameters:
        - DEPS_FILE = deps_file
        - COMMAND_FILE = command_file
        - STAMP_FILE = stamp_file
        - WORKING_DIRECTORY = binary_dir
        - LOG_FILE = log_file
        - LOG_OUTPUT_ON_FAILURE = get_log_output_on_failure_setting()
        - DEBUG = debug
```

### Build-Time Execution

PSEUDOCODE:
```
FUNCTION setup_dependency_checker_build_time(name, step, binary_dir, log_dir, debug):
    deps_file = get_dependency_file_path(name, step)
    command_file = get_command_file_path(name, step)
    stamp_file = get_stamp_file_path(name, step)
    log_file = get_log_file_path(name, step, log_dir)
    
    checker_script = get_checker_script_path()
    
    Create custom build command that:
        - Outputs to stamp_file
        - Depends on deps_file and command_file
        - Executes the dependency checker script with parameters:
            * DEPS_FILE = deps_file
            * COMMAND_FILE = command_file
            * STAMP_FILE = stamp_file
            * WORKING_DIRECTORY = binary_dir
            * LOG_FILE = log_file
            * LOG_OUTPUT_ON_FAILURE = get_log_output_on_failure_setting()
            * DEBUG = debug
        - Runs in working directory: binary_dir
        - Shows comment: "Prerequisite [name]: Running [step] step"
```

## Key Improvements Over checker_design_2.md

1. **Platform-Specific Command Parsing**
   - Windows-specific handling preserves command structure
   - Properly handles Windows command-line quirks
   - Maintains UNIX-style parsing for non-Windows platforms

2. **Enhanced Progress Feedback**
   - Always shows command being executed
   - Provides visibility during long-running operations
   - Better user experience while maintaining logging options

3. **Partial Command Execution Tracking**
   - Tracks which commands succeeded before failure
   - Provides clear feedback about progress when failures occur
   - Makes multi-command steps more debuggable

4. **Complete LOG_* Integration**
   - Properly implements LOG_OUTPUT_ON_FAILURE
   - Maintains console output visibility during execution
   - Captures full output to logs when requested

5. **Windows Double-Execution Resolution**
   - The dependency checker only executes when needed
   - Visual Studio generator no longer triggers unnecessary rebuilds
   - Consistent behavior across all generators

## Advantages Over Current Approach

1. **Consistent behavior**: Same logic executes during configure-time and build-time
2. **Reliable command execution**: Proper handling of complex commands across platforms
3. **Better dependency tracking**: Explicit verification before execution
4. **Simplified architecture**: Single stamp file with clear responsibilities
5. **Enhanced logging**: Unified approach across execution modes
6. **Windows compatibility**: Resolves double-execution issue with Visual Studio
7. **User experience**: Provides progress feedback during long operations

## Migration Path

1. Implement dependency checker script with platform-specific parsing
2. Update `_Prerequisite_Create_Wrapper_Script` to generate command and dependency files
3. Replace two-stamp architecture with single stamp
4. Update all prerequisite steps to use dependency checker
5. Add comprehensive tests for Windows behavior

## Testing Strategy

1. **Basic functionality test**: Verify command runs when stamp missing
2. **Dependency test**: Verify command runs when dependency updated
3. **No-op test**: Verify command doesn't run when up-to-date
4. **Windows command test**: Verify complex Windows commands work correctly
5. **Progress feedback test**: Verify user gets visibility during long operations
6. **Partial failure test**: Verify proper reporting when multi-command steps fail
7. **Visual Studio generator test**: Verify no double-execution with VS generator

This final design resolves the Windows double-execution issue while addressing all critical concerns identified in previous iterations, resulting in a robust, maintainable solution that works consistently across all platforms.
