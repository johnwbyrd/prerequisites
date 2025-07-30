# Prerequisites System TODO (July 2025)

## CRITICAL: Smart Wrapper Scripts Implementation - PARTIAL SUCCESS

### Current Status Summary

**PROGRESS**: Smart wrapper scripts implemented successfully, but diagnostic issue discovered.

**Test Results**:
- ✅ **Overall improvement**: 86% pass rate (24/28) vs previous 81% (21/26)
- ✅ **Wrapper script logic**: Working correctly, includes dependency checking
- ❌ **Configure-time execution**: Commands not executing during configure phase

**Specific Failures**:
- `stamp/incremental_build`: "download step executed 0 times, expected 1"
- File dependency tests: Commands executing when they shouldn't (count = 2)

## CURRENT DIAGNOSTIC ISSUE

### Problem: Configure-Time vs Build-Time Inconsistency

**Expected Behavior** (clean build):
1. **Configure-time**: No stamps exist, commands execute once (count = 1)
2. **Build-time**: Stamps exist, commands skip execution (count stays 1)

**Actual Behavior**:
1. **Configure-time**: Commands not executing (count = 0)
2. **Build-time**: Commands executing when they shouldn't (count = 2)

**Key Questions to Resolve**:
1. **Why are post-stamps present** in a clean build before any commands execute?
2. **Are both execution paths running** and interfering with each other?
3. **Should configure-time also use wrapper scripts** instead of direct execution?

### Implementation Status

**What's Working**:
- ✅ Wrapper script generation and dependency checking logic
- ✅ CMake script delegation for complex dependency checking
- ✅ Platform-specific Windows batch and Unix shell implementations
- ✅ Debug output and error handling

**What Needs Investigation**:
- ❌ Configure-time execution path (why commands don't run)
- ❌ Post-stamp creation timing (why they exist prematurely)
- ❌ Execution path coordination (configure vs build interference)

## COMPLETED: Smart Wrapper Scripts Implementation 

### Windows Compatibility Issue - RESOLVED

**Problem**: Build-time wrapper scripts were executing commands when they should have skipped them, causing double execution (count = 2 instead of 1).

**Root Cause**: Dependency checker scripts used `execute_process(COMMAND ${CMAKE_COMMAND} -E false)` to signal "up to date" status, but this doesn't set the CMake script's exit code. Scripts always returned 0, causing wrapper scripts to execute commands.

**Solution**: Changed dependency checker to use `message(FATAL_ERROR "DEPENDENCIES_UP_TO_DATE")` when dependencies are up-to-date. This correctly returns non-zero exit code that wrapper scripts interpret as "skip execution."

**Verification**: ✅ Clean configure → build → build cycle shows correct behavior:
- Configure-time: Commands execute once (count = 1)
- Build-time: Commands correctly skip (count stays 1)
- Subsequent builds: Commands continue to skip correctly

### Files Modified - Smart Wrapper Scripts

**Primary Implementation**:
- ✅ `cmake/Prerequisite.cmake` lines 580-637: `_Prerequisite_Generate_Dependency_Checker()` (NEW)
- ✅ `cmake/Prerequisite.cmake` lines 640-742: `_Prerequisite_Create_Wrapper_Script()` (ENHANCED) 
- ✅ `cmake/Prerequisite.cmake` line 746: `_Prerequisite_Create_Build_Target()` signature (UPDATED)
- ✅ `cmake/Prerequisite.cmake` line 885: Function call updated with dependency info
- ✅ `cmake/Prerequisite.cmake` line 649: Fixed dependency checker exit code logic

## NEXT PRIORITY: Reconfigure Behavior Implementation

### Reconfigure Behavior Design Decision

**Issue**: Prerequisites system has inconsistent reconfigure behavior:
- Initial configure: Commands execute regardless of existing stamps (clean build authority)
- Reconfigure: Commands respect existing stamps and may skip execution (performance optimization)

**Design Decision - Hybrid Approach**:

**Default Behavior**: Clean stamps on reconfigure (configure is authoritative)
- Simple, predictable behavior: "configure = rebuild prerequisites" 
- Most prerequisites are small/fast, so clean-by-default is acceptable
- Maintains "configure is authoritative" principle

**Per-Prerequisite Override**: New `RECONFIGURE_BEHAVIOR` option
```cmake
Prerequisite_Add(llvm
    RECONFIGURE_BEHAVIOR RESPECT_STAMPS  # Keep expensive builds
)
Prerequisite_Add(my_small_tool
    # Uses default CLEAN_STAMPS behavior
)
```

**Emergency Override**: Environment variable `PREREQUISITE_FORCE_CLEAN=1`
- Global override when stamp-respecting behavior causes issues

### Implementation Tasks

1. **Add RECONFIGURE_BEHAVIOR option parsing** in `_Prerequisite_Parse_Arguments`
2. **Implement stamp cleaning logic** in configure-time execution path
3. **Add environment variable check** for global override
4. **Update documentation** with new option and behavior
5. **Add tests** for reconfigure behavior scenarios

## SECONDARY PRIORITIES

1. **Download Source Support** (GIT_REPOSITORY, URL)
2. **Full Step Implementation** (UPDATE_COMMAND, CONFIGURE_COMMAND, TEST_COMMAND)  
3. **Logging System** (LOG_* options)
4. **Advanced File Dependencies** (DOWNLOAD_DEPENDS, etc.)

## Success Criteria

**Immediate Goal**: ✅ COMPLETED - Windows compatibility resolved
**Next Goal**: Implement reconfigure behavior with user control
**Final Goal**: 100% test pass rate with comprehensive reconfigure behavior support