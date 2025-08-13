# Prerequisites Dependency Checker Implementation Plan

## Current State Analysis

1. **Single Stamp Architecture**: The current implementation in `Prerequisite.cmake` is already using a single stamp approach, not the old two-stamp system. Each step creates one stamp file at `${STAMP_DIR}/${name}-${step}`.

2. **Wrapper Script Approach**: The current implementation uses `_Prerequisite_Create_Wrapper_Script` function that:
   - Creates platform-specific wrapper scripts (.bat on Windows, .sh on Unix)
   - These scripts execute commands and create stamp files on success
   - Used in build-time targets via `add_custom_command`

3. **Dependency Checking**: The current implementation has basic dependency checking:
   - For file dependencies, it compares file timestamps with stamp files
   - For stamp-only dependencies, it just checks if the stamp file exists

## What Needs to be Implemented

According to `docs/dependency_checker.md`, the plan is to replace the current approach with a "unified dependency checker" that:

1. **Unified Architecture**: Works identically during configure-time (`execute_process()`) and build-time (`add_custom_command()`)
2. **File-based Configuration**: Uses dependency list files and command list files instead of embedding logic in wrapper scripts
3. **Enhanced Dependency Checking**: More robust dependency verification before command execution
4. **Better Error Handling**: Improved logging and error reporting

## Implementation Plan

### Phase 1: Create Dependency Checker Function

1. Implement a `_Prerequisite_Execute_Dependency_Checker` function that:
   - Takes dependency list file, command list file, and stamp file as parameters
   - Reads and validates dependencies before execution
   - Executes commands with proper logging
   - Creates stamp file on success, removes on failure

### Phase 2: Update Wrapper Script Generation

1. Modify `_Prerequisite_Create_Wrapper_Script` to:
   - Generate dependency list files (one path per line)
   - Generate command list files (CMake list format, one command per line)
   - Create wrapper scripts that call the dependency checker instead of executing commands directly

### Phase 3: Update Immediate Execution

1. Modify `_Prerequisite_Execute_Immediate` to use the dependency checker approach instead of direct command execution

### Phase 4: Testing and Validation

1. Run existing tests to ensure no regressions
2. Add new tests for the dependency checker functionality

## Key Design Principles

The dependency checker approach separates the concerns:
- Dependency checking logic is in the dependency checker
- File generation is handled by the build system
- Wrapper scripts just call the dependency checker with appropriate parameters

This provides better consistency between configure-time and build-time execution, improved error handling, and more maintainable code.
