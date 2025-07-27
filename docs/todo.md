# Prerequisites System TODO (July 2025)

## CRITICAL: Build-Time Execution Issue - ANALYSIS COMPLETE

### Current Status Summary

**PROGRESS**: Root cause identified. Wrapper scripts lack dependency checking logic.

**Test Results**:
- ✅ **Configure-only tests**: Pass (using smart dependency logic)
- ❌ **Build tests**: Fail due to wrapper scripts always executing

### Root Cause Analysis: COMPLETED

**The Problem**: Wrapper scripts are "dumb" - they always execute commands when invoked, while configure-time logic is "smart" with proper dependency checking.

**Evidence**:
- Configure-time execution has dependency checking (works correctly)
- Build-time wrapper scripts have no dependency checking (always execute)
- Test logs show "Counter incremented to 2" (should be 1)

### Technical Analysis

**Current Wrapper Script Logic**:
```bash
# Always runs, no dependency checking
user_command
touch "post_stamp_file"
```

**Configure-Time Logic** (from `_Prerequisite_Process_Single_Step`):
- Checks if post-stamp exists
- For file dependencies: Checks if any tracked files are newer than post-stamp
- Only executes if work is actually needed

**The Fundamental Problem**: Wrapper scripts need the same dependency checking intelligence as configure-time execution.

## IMMEDIATE PRIORITY: Smart Wrapper Scripts

### Solution Requirements

**Generic Solution**: Make wrapper scripts intelligent about when execution is needed
- Extract dependency checking logic into reusable functionality
- Generate smart wrapper scripts that check dependencies before executing
- Handle command-line length limits appropriately

### Implementation Approach

#### Phase 1: Extract Dependency Logic
- Move dependency checking from `_Prerequisite_Process_Single_Step` (lines 720-757)
- Create reusable function for both configure-time and wrapper scripts

#### Phase 2: Smart Wrapper Script Generation
- Pass dependency information to `_Prerequisite_Create_Wrapper_Script()`
- Generate dependency checking code in wrapper scripts
- Handle both stamp-only and file dependency cases
- Always use dependency list files (assume many globbed files)

#### Phase 3: Windows Batch Implementation
**Keep it simple** - Windows batch has limited control flow:
```batch
@echo off
REM Check dependencies via CMake script (handles complex logic)
"${CMAKE_COMMAND}" -P "${CHECK_DEPS_SCRIPT}" "${POST_STAMP}" "${DEP_LIST_FILE}"
if %errorlevel% equ 0 (
    REM Dependencies indicate work needed
    ${COMMAND}
    if %errorlevel% equ 0 (
        "${CMAKE_COMMAND}" -E touch "${POST_STAMP}"
    ) else (
        "${CMAKE_COMMAND}" -E remove -f "${POST_STAMP}"
        exit /b %errorlevel%
    )
)
```

#### Dependency Checking Strategy
- **Always use list files**: Assume many globbed dependencies
- **Fatal on missing**: Dependencies missing at build time = error
- **CMake script delegation**: All complex logic in CMake, not shell scripts
- **Generate once**: All scripts/files generated at configure time

### Implementation Location

**Primary Files**:
- `cmake/Prerequisite.cmake` lines 594-604: Wrapper script generation
- `cmake/Prerequisite.cmake` lines 720-757: Dependency checking logic to extract

### Validation Plan

**Test both modes**:
- Configure-time: Should continue working as before
- Build-time: Wrapper scripts should only execute when dependencies change

**Success Criteria**: 100% test pass rate with consistent behavior between modes

## SECONDARY PRIORITIES (Deferred Until Core Fix)

1. **Download Source Support** (GIT_REPOSITORY, URL) - Currently parsed but not implemented
2. **Full Step Implementation** (UPDATE_COMMAND, CONFIGURE_COMMAND, TEST_COMMAND) 
3. **Logging System** (LOG_* options) - Currently parsed but ignored
4. **Advanced File Dependencies** (DOWNLOAD_DEPENDS, CONFIGURE_DEPENDS, etc.)

## Critical Understanding for Next Context

**The Prerequisites system architecture is sound** - the issue is missing dependency logic in wrapper scripts. The solution is making wrapper scripts as intelligent as configure-time execution, NOT platform-specific hacks.

**Key Insight**: The difference between working configure-time execution and failing build-time execution is the presence/absence of dependency checking logic.