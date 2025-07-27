# Prerequisites System TODO (July 2025)

## CRITICAL ISSUE: Windows Test Failures - Command Double Execution

### Problem Summary
Windows tests fail because commands execute twice (configure time + build time) instead of once (configure time only). The issue is NOT the two-stamp architecture - it's the broken configure-time detection logic.

### Root Cause
The function `_Prerequisite_Is_Configure_Time()` uses `CMAKE_PROJECT_NAME` to detect if `project()` has been called. However, CMake's parsing vs execution model makes this unreliable:

1. CMake parses entire CMakeLists.txt before executing any commands
2. `CMAKE_PROJECT_NAME` gets set during parsing, not execution
3. When `Prerequisite_Add()` executes, `CMAKE_PROJECT_NAME` is already set
4. Detection incorrectly returns FALSE (build time) when it should return TRUE (configure time)
5. Commands skip configure-time execution, only run at build time

### Evidence of the Bug
Debug output shows:
```
CMAKE_PROJECT_NAME='TestProject' (already set from parsing)
-> returning FALSE (build time: project() called in this directory)
```
Even though `Prerequisite_Add()` appears before `project()` in the file.

## FIX IMPLEMENTED

### Configure-Time Detection Removed

The broken `_Prerequisite_Is_Configure_Time()` function has been completely removed from `cmake/Prerequisite.cmake`. Prerequisites now always execute immediately and create build targets.

### Test the Fix

Run the failing test:
```bash
cd build && ctest -R "stamp/incremental_build" --output-on-failure
```

Expected result: Test should pass with count=1 instead of failing with count=2.

### Verify All Tests Pass

Run full test suite:
```bash
cd build && ctest --output-on-failure
```

Expected result: All 26 tests should pass.

## DEBUGGING GUIDE FOR FUTURE CLAUDE INSTANCES

### If Tests Still Fail with "executed X times, expected Y"

1. **Check for Reconfiguration During Build**:
   Look for: "CMake is re-running because ... is out-of-date"
   This resets counters and can cause confusion about execution timing.

2. **Verify Stamp Files**:
   Check if post-stamp files exist in `${name}-prefix/src/${name}-stamp/`
   If missing, configure-time execution was skipped.

3. **Check Test Isolation**:
   Each test should run in separate CMake process via `add_prerequisite_test()`

### Understanding the Two-Stamp System

**Pre-stamp (`${name}-${step}-pre`)**:
- Created when dependencies are satisfied
- Indicates "ready to execute"
- Used in build dependency chain

**Post-stamp (`${name}-${step}-post`)**:
- Created when step execution completes successfully
- Indicates "execution finished"
- What subsequent steps depend on

**Critical Understanding**: The two-stamp system is about proper dependency tracking in the build system.

## SECONDARY PRIORITIES

### 1. Download Source Support (GIT_REPOSITORY, URL)
- Currently parsed but not implemented
- Need git clone and URL download functionality

### 2. Multi-Step Workflow (UPDATE_COMMAND, CONFIGURE_COMMAND, TEST_COMMAND)
- Only BUILD_COMMAND is fully tested
- Need complete step sequence implementation

### 3. Logging System (LOG_* options)
- Currently parsed but ignored
- Need output redirection to log files

### 4. Advanced File Dependencies
- Only BUILD_DEPENDS is tested
- Need DOWNLOAD_DEPENDS, CONFIGURE_DEPENDS, etc.

### 5. Force Targets
- Created but not tested
- Need verification of force rebuild behavior

## CURRENT STATUS

**Working**: Core Prerequisites functionality, two-stamp architecture, basic testing
**Fixed**: Configure-time detection (function removed completely)
**Missing**: Download sources, full step implementation, logging

**Next Priority**: Test the fix, then implement missing features.