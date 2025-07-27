# Prerequisites System TODO (July 2025)

## CRITICAL: Windows Double Execution Fix - PARTIALLY IMPLEMENTED

### Implementation Progress (54% Test Pass Rate)

**COMPLETED**:
- ✅ Root cause analysis: CMake `add_custom_command()` OUTPUT semantics conflict on Windows
- ✅ Wrapper script generation architecture designed and implemented
- ✅ `_Prerequisite_Create_Wrapper_Script()` function completed
- ✅ Platform-specific script generation (Windows .bat, Unix .sh)
- ✅ Integration with `_Prerequisite_Create_Build_Target()`
- ✅ Cross-platform script template system

**CURRENT ISSUE**: Command list parsing error
- **Symptom**: `/c: /c: Is a directory` error during test execution
- **Root Cause**: CMake interpreting `cmd /c` as separate command and argument instead of command with argument
- **Location**: `_Prerequisite_Create_Wrapper_Script()` line 583: `set(${out_execute_command} ${executor} "${script_file}" PARENT_SCOPE)`

### Immediate Next Task (HIGH PRIORITY)

**Fix command list construction** in `_Prerequisite_Create_Wrapper_Script()`:
- Current: `set(executor cmd /c)` creates CMake list `[cmd, /c]`
- Problem: `add_custom_command(COMMAND ${execute_command})` treats as command=`cmd`, arg1=`/c`, arg2=`script`
- Solution: Build proper command list structure for CMake

### Validated Working Components

**Wrapper Script Generation**: ✅ WORKING
- Scripts created at `${CMAKE_BINARY_DIR}/prerequisite-wrappers/${name}/${step}-wrapper.bat`
- Correct stamp checking logic: `if exist "stamp" exit /b 0`
- Proper error propagation: `if %errorlevel% neq 0 exit /b %errorlevel%`
- Cross-platform compatibility maintained

**vcxproj Integration**: ✅ IMPROVED
- Clean command execution in generated Visual Studio projects
- No more mangled quoted strings
- Shows: `cmd /c C:/path/to/script.bat` (correct format)

**Test Infrastructure**: ✅ FUNCTIONAL
- 14/26 tests passing (54% pass rate)
- All non-build tests passing (configure-time execution working)
- All build-time failures due to same command parsing issue

### Implementation Functions Added

```cmake
# Location: cmake/Prerequisite.cmake lines 538-584
function(_Prerequisite_Create_Wrapper_Script name step command_list post_stamp_file out_execute_command)
    # Creates platform-specific wrapper scripts with stamp checking
    # Status: IMPLEMENTED, needs command list fix
endfunction()
```

**Modified**: `_Prerequisite_Create_Build_Target()` lines 613-622
- Replaced direct command execution with wrapper script approach
- Integration working, command parsing needs fix

### Architecture Validation

**Cross-Platform Design**: ✅ CONFIRMED
- Windows: `@echo off` + batch syntax
- Unix: `#!/bin/bash` + shell syntax  
- Both: Proper error codes and stamp creation

**CMake Integration**: ⚠️ PARTIAL
- Script generation: Working
- File permissions (Unix): Working (`file(CHMOD)`)
- Command execution: Needs parsing fix

## SECONDARY PRIORITIES (Deferred Until Fix Complete)

1. **Download Source Support** (GIT_REPOSITORY, URL) - Currently parsed but not implemented
2. **Full Step Implementation** (UPDATE_COMMAND, CONFIGURE_COMMAND, TEST_COMMAND) 
3. **Logging System** (LOG_* options) - Currently parsed but ignored
4. **Advanced File Dependencies** (DOWNLOAD_DEPENDS, CONFIGURE_DEPENDS, etc.)

## SUCCESS CRITERIA

**Target**: 100% test pass rate (currently 54%)
**Blocker**: Single command parsing issue affecting all build-time tests
**Timeline**: Should be resolved in single session once command list construction is fixed

The wrapper script approach is fundamentally sound and nearly complete. The remaining issue is a specific CMake command construction problem, not an architectural flaw.