# Todo

## Current Status (July 2025)

**Prerequisites System: CORE FUNCTIONALITY COMPLETE BUT WINDOWS COMPATIBILITY ISSUE IDENTIFIED**
- Dual execution model fully implemented and tested (26/26 tests passing on Linux)
- **CRITICAL ISSUE**: Windows builds fail due to stamp file architecture semantic conflict
- Configure-time detection working in nested CMake contexts (CTest)
- File dependency tracking with GLOB patterns implemented
- Variable substitution system working for all supported variables
- Build target generation and force targets
- Property storage and retrieval system complete
- Comprehensive test suite covering core functionality

**Windows Compatibility Problem:**
- Current single-stamp architecture pre-creates stamp files during configure time
- Then declares same files as OUTPUT in build-time custom commands
- Visual Studio generators reject this pattern (works on Linux/Make generators)
- Results in commands re-executing at build time despite existing stamps

**Solution Identified: Two-Stamp Architecture**
- Documented in `docs/CLAUDE.md` under "Stamp File Architecture Analysis"
- Pre-stamp: "Dependencies satisfied, ready to execute" 
- Post-stamp: "Execution completed successfully"
- Eliminates semantic conflict by never pre-creating OUTPUT files

## CRITICAL PRIORITY: Configure-Time Detection Issue

### 1. Fix Configure-Time Detection Logic (BLOCKING ALL OTHER WORK)

**Objective**: Fix fundamental issue with `_Prerequisite_Is_Configure_Time()` function that is causing Prerequisites to incorrectly detect build-time when they should execute at configure-time.

**Problem Discovered**: During Ubuntu testing of two-stamp architecture, found that `CMAKE_PROJECT_NAME` is already set when `Prerequisite_Add()` executes, even though `Prerequisite_Add()` appears before `project()` in CMakeLists.txt files.

**Impact**: 
- BLOCKING: Cannot test Windows compatibility fix
- CRITICAL: Dual-execution model is broken 
- SEVERE: Bootstrap functionality may be compromised across all platforms

**Evidence**:
```
# File order in tests/simple/immediate/CMakeLists.txt:
Line 18: Prerequisite_Add(immediate ...)
Line 35: project(ImmediateTest LANGUAGES NONE)

# But debug output shows:
CMAKE_PROJECT_NAME='ImmediateTest' <- ALREADY SET!
-> returning FALSE (build time: project() called in this directory)
```

**Current Test Status**: 6/26 tests failing on Ubuntu (was 26/26 passing before two-stamp changes)

**Root Cause Analysis COMPLETED**:

**Key Finding**: The detection logic is fundamentally flawed due to CMake's parsing vs execution model.

1. **CMake Parsing Behavior**: CMake parses the entire CMakeLists.txt file before executing any commands, including `project()` calls. This sets `CMAKE_PROJECT_NAME` during parsing, not execution.

2. **Test Framework Analysis**: Isolated testing outside the test framework proves the detection logic works correctly when no `project()` call exists in the file.

3. **Execution Model Clarification**: 
   - `Prerequisite_Add()` **always** runs at configure time (during `cmake` execution)
   - Build-time execution happens via `add_custom_command()` shell commands, not CMake code
   - Both immediate execution AND build target creation should happen during configure time

4. **Current Detection Flaw**: Using `CMAKE_PROJECT_NAME` to detect "has project() been called" is unreliable because it's set during parsing regardless of execution order.

**Proposed Solution Approach**:

**Core Insight**: Since `Prerequisite_Add()` always runs at configure time, we should:
1. **Always create build targets** (for development workflow)
2. **Default to immediate execution** (for bootstrapping use case)  
3. **Optionally warn about potential misuse** (if `project()` appears to have been called)

**Simplified Detection Logic**:
```cmake
function(_Prerequisite_Is_Configure_Time out_var)
  # Default to immediate execution (primary use case: bootstrapping)
  set(execute_immediately TRUE)
  
  # Warn if project() may have been called in same directory
  if(CMAKE_PROJECT_NAME AND "${CMAKE_SOURCE_DIR}" STREQUAL "${CMAKE_CURRENT_SOURCE_DIR}")
    message(WARNING "Prerequisite_Add() may be called after project() in same directory. "
                    "For bootstrapping, Prerequisites should appear before project().")
  endif()
  
  set(${out_var} ${execute_immediately} PARENT_SCOPE)
endfunction()
```

**Potential Issues with This Approach**:
1. **False positive warnings**: Correct file order may still trigger warnings due to parsing behavior
2. **Doesn't fix root cause**: Still relies on unreliable `CMAKE_PROJECT_NAME` detection
3. **Test compatibility**: Tests expecting no warnings may fail

**Testing Results - PROJECT_NAME vs CMAKE_PROJECT_NAME**:

**Hypothesis Tested**: Whether `PROJECT_NAME` has different timing behavior than `CMAKE_PROJECT_NAME` and could provide reliable detection.

**Test Results**: Both variables behave identically regarding parsing vs execution timing:
```
BEFORE project() call:
  CMAKE_PROJECT_NAME=''     PROJECT_NAME=''
  Current logic: TRUE       New logic: TRUE

AFTER project() call:  
  CMAKE_PROJECT_NAME='TestProject'     PROJECT_NAME='TestProject'
  Current logic: FALSE     New logic: FALSE
```

**Conclusion**: `PROJECT_NAME` suffers from the same fundamental issue as `CMAKE_PROJECT_NAME`. Both get set during CMake's parsing phase regardless of command execution order.

**Implication**: The two-phase processing approach using `PROJECT_NAME` detection would have the exact same problem - Prerequisites appearing before `project()` in correctly-written files would still incorrectly detect "post-project" state.

**Alternative Approaches to Consider**:

**1. Remove Detection Entirely (RECOMMENDED)**:
```cmake
function(Prerequisite_Add name)
  # Always do both:
  # 1. Execute immediately (for bootstrapping)
  # 2. Create build targets (for development workflow)
  
  # No detection needed - always bootstrap, always create targets
  _Prerequisite_Execute_Immediate(...)
  _Prerequisite_Create_Build_Target(...)
endfunction()
```

**Pros**: Simple, reliable, matches primary use case
**Cons**: May execute unnecessarily in some edge cases

**2. Explicit Mode Parameter**:
```cmake
Prerequisite_Add(name IMMEDIATE ...)  # Force immediate execution
Prerequisite_Add(name DEFERRED ...)   # Force deferred execution  
Prerequisite_Add(name ...)             # Default behavior (immediate)
```

**Pros**: Explicit user control, no guessing
**Cons**: API change, requires user to understand timing

**3. Default + Override**:
```cmake
Prerequisite_Add(name ...)             # Immediate by default
Prerequisite_Add(name DEFERRED ...)    # Override to deferred when needed
```

**Pros**: Backward compatible, covers main use case
**Cons**: Still requires user understanding of timing

**4. Environment-Based Control**:
```cmake
set(PREREQUISITE_EXECUTION_MODE "IMMEDIATE" CACHE STRING "Control execution mode")
# Or detection via CMAKE_ROLE for context awareness
```

**Pros**: Global control, good for testing
**Cons**: Hidden behavior, not explicit in code

**Recommended Implementation Plan**:

**Phase 1: Fix Current Bugs (Immediate)**
1. **Implement "Remove Detection Entirely" approach**:
   - Modify `_Prerequisite_Is_Configure_Time()` to always return TRUE
   - Always execute immediately AND always create build targets
   - Remove complex detection logic entirely

2. **Update Tests**:
   - Verify all 26 tests pass with simplified logic
   - Tests should work correctly since they expect immediate execution
   - No changes to test files needed - just fix the implementation

3. **Test Windows Compatibility**:
   - With immediate execution working, test two-stamp architecture on Windows
   - Verify Windows build failures are resolved

**Phase 2: Enhanced Control (Future)**
1. **Add Optional DEFERRED Parameter**:
   - `Prerequisite_Add(name DEFERRED ...)` for edge cases
   - Default behavior remains immediate execution
   - Backward compatible with existing code

2. **Document Usage Patterns**:
   - Clarify that Prerequisites should appear before `project()`
   - Document the dual execution model (immediate + targets)
   - Provide examples of proper usage

**Implementation Code for Phase 1**:
```cmake
function(_Prerequisite_Is_Configure_Time out_var)
  # Simplified: Always execute immediately and always create targets
  # This matches the primary use case and eliminates detection issues
  set(${out_var} TRUE PARENT_SCOPE)
endfunction()
```

**Testing Strategy**:
- Run existing test suite - all tests should pass
- Test isolation example (debug_tests/CMakeLists.txt) - should work correctly  
- Test Windows build with Visual Studio generator
- Verify no performance regression in normal development

**Priority**: MUST be resolved before any Windows testing or further development

## Secondary Priority: Windows Compatibility Fix

### 2. Complete Two-Stamp Architecture Testing (DEPENDS ON #1)

**Objective**: Once configure-time detection is fixed, complete testing of two-stamp system to fix Windows build failures.

**Implementation Status: COMPLETED BUT UNTESTED**

**Changes Made:**
1. **Modified `_Prerequisite_Create_Build_Target()` function** (cmake/Prerequisite.cmake:595)
   - ✅ Replaced single `add_custom_command()` with two commands
   - ✅ First: `OUTPUT pre_stamp DEPENDS prev_post_stamp file_deps COMMAND cmake -E touch pre_stamp`
   - ✅ Second: `OUTPUT post_stamp DEPENDS pre_stamp COMMAND actual_step_commands`

2. **Updated stamp file naming convention**
   - ✅ Pre-stamp: `${STAMP_DIR}/${name}-${step}-pre`
   - ✅ Post-stamp: `${STAMP_DIR}/${name}-${step}-post` (replaces current stamp)
   - ✅ Updated all stamp file path generation throughout codebase

3. **Implemented inline wrapper logic**
   - ✅ Used inline CMake commands in the custom command (simpler approach)
   - ✅ Logic: Run actual command, create post-stamp on success, exit with error on failure

4. **Updated configure-time execution logic** (_Prerequisite_Execute_Immediate)
   - ✅ Create pre-stamp when execution begins
   - ✅ Create post-stamp ONLY if step completes successfully  
   - ✅ On failure: clean up both pre and post stamps for failed and subsequent steps
   - ✅ Updated dependency checking logic to use post-stamp files
   - ✅ Added user-friendly error messages without referencing stamp implementation

5. **Updated inter-step dependencies**
   - ✅ Steps depend on previous step's post-stamp (not pre-stamp)
   - ✅ Updated `_Prerequisite_Process_Single_Step()` dependency chain construction
   - ✅ Force targets remove post-stamp only (simpler approach)

**Testing Requirements:**
- ⏳ All existing tests must pass with two-stamp system
- ⏳ Verify Windows compatibility (no more build failures)
- ⏳ Verify no performance regression in normal development workflow
- ⏳ Test failure recovery behavior

**Files Modified:**
- ✅ `cmake/Prerequisite.cmake` (main implementation)
- ⏳ `docs/CLAUDE.md` (update status once tested)
- ⏳ Tests may need updates if they check specific stamp file names

### 2. Download Source Support (DEFERRED UNTIL AFTER WINDOWS FIX)

**Git-based downloads:**
- `GIT_REPOSITORY` and `GIT_TAG` - No implementation or testing
- `GIT_SHALLOW` - No shallow clone support
- Git authentication and credentials handling

**URL-based downloads:**  
- `URL` and `URL_HASH` - No URL download implementation
- `DOWNLOAD_NO_EXTRACT` - No archive extraction control
- HTTP authentication and retry mechanisms

**Implementation approach:**
- Add Git and URL detection logic to download step
- Implement git clone, wget/curl download commands
- Add hash verification for URL downloads
- Create comprehensive download tests with mocked tools

### 3. Multi-Step Workflow Support (DEFERRED UNTIL AFTER WINDOWS FIX)

**Missing step implementations:**
- `UPDATE_COMMAND` - Update step completely unimplemented
- `CONFIGURE_COMMAND` - Configure step not implemented  
- `TEST_COMMAND` - Test step not implemented

**Step sequence issues:**
- Only BUILD step is comprehensively tested
- Step chaining logic exists but untested for most steps
- DOWNLOAD and INSTALL steps have basic support only

**Required work:**
- Implement remaining step command execution
- Add comprehensive multi-step integration tests
- Validate step dependency chains (download → update → configure → build → install → test)

### 4. Logging System (DEFERRED UNTIL AFTER WINDOWS FIX)

**Unimplemented logging options:**
- `LOG_DOWNLOAD`, `LOG_UPDATE`, `LOG_CONFIGURE`, `LOG_BUILD`, `LOG_INSTALL`, `LOG_TEST`
- `LOG_OUTPUT_ON_FAILURE` - Conditional output display
- Log file naming and directory management

**Current state:**
- All LOG_* options are parsed and stored but completely ignored
- No log redirection or capture functionality
- No log file creation or management

**Implementation needs:**
- Add output redirection to step execution functions
- Implement log file creation in LOG_DIR/STAMP_DIR
- Add failure-conditional log display
- Test all logging scenarios

### 5. Directory Customization (DEFERRED UNTIL AFTER WINDOWS FIX)

**Untested directory options:**
- `PREFIX`, `SOURCE_DIR`, `BINARY_DIR`, `INSTALL_DIR`, `STAMP_DIR`, `LOG_DIR`
- Custom directory inheritance and defaults
- Directory creation and validation

**Current limitation:**
- Default directory structure works fine
- Custom directory specification untested
- No validation of directory option interactions

### 6. Advanced Features (DEFERRED UNTIL AFTER WINDOWS FIX)

**Force targets:**
- `<name>-force-<step>` targets exist but no tests verify behavior
- Force rebuild mechanism untested
- Force target chaining untested

**Property retrieval:**
- `Prerequisite_Get_Property` function exists but minimal testing
- Property enumeration and validation untested

**Advanced file dependencies:**
- `DOWNLOAD_DEPENDS`, `UPDATE_DEPENDS`, `CONFIGURE_DEPENDS`, `INSTALL_DEPENDS`, `TEST_DEPENDS`
- Only `BUILD_DEPENDS` is tested
- `GLOB_RECURSE` patterns untested

**Variable substitution gaps:**
- `@PREREQUISITE_PREFIX@`, `@PREREQUISITE_INSTALL_DIR@`, `@PREREQUISITE_STAMP_DIR@`, `@PREREQUISITE_LOG_DIR@`
- Only basic variables tested (`NAME`, `BINARY_DIR`, `SOURCE_DIR`)

## Implementation Notes for Two-Stamp Architecture

**Key Design Principles (from analysis in docs/CLAUDE.md):**
1. Pre-stamp and post-stamp are both OUTPUT of custom commands (never pre-existing)
2. Dependency chain: `file_deps + prev_post_stamp → pre_stamp → post_stamp`
3. Configure-time execution creates pre-stamp on start, post-stamp only on success
4. Build-time custom commands handle incremental updates
5. Failed executions leave pre-stamp without post-stamp (diagnostic state)

**Debug Approach:**
- Debug logging already added to `_Prerequisite_Create_Build_Target()` 
- Shows OUTPUT and DEPENDS declarations made to build system
- Can be used to verify two-stamp commands are created correctly

**Validation Criteria:**
- Windows test failures (`stamp/incremental_build` etc.) must pass
- No performance regression in Linux builds  
- Same incremental build behavior as current system
- Clear diagnostic information when builds fail

## Medium Priority Extensions (POST WINDOWS FIX)

### 1. Prerequisite Dependencies (BASIC IMPLEMENTATION EXISTS)
- `DEPENDS <prereqs...>` option parsed but testing is limited
- Multi-prerequisite dependency chains need validation
- Build-time vs configure-time dependency behavior testing

### 2. Control Options (POST WINDOWS FIX)
- `<STEP>_ALWAYS` flags - Parsed but no implementation or testing
- `BUILD_IN_SOURCE` - No implementation
- Advanced step control mechanisms

### 3. Platform Integration Preparation (POST WINDOWS FIX)
- Prerequisites → platforms integration design
- External tool discovery (find existing installations vs building)
- Toolchain integration patterns