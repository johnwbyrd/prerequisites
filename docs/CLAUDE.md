## Prerequisites System

### The bootstrapping problem

The CMake prerequisites system solves the fundamental problem of building compilers and libraries before CMake's project() command can detect them. This system is essential where custom toolchains must often be built from source.

Traditional CMake projects assume that compilers and essential libraries already exist when configuration begins. The project() statement triggers compiler detection, feature tests, and library searches. But this creates ordering challenges when you need to build the very tools that CMake is about to look for. CMake needs these tools to configure your project, but you need CMake to build the tools.

The prerequisites system breaks this deadlock by operating before the project() command runs. It can build your dependencies immediately during configuration so they're ready when project() executes, while also creating normal CMake targets for incremental rebuilds later.

### Dual execution model

The prerequisites system operates in both configure time and build time modes. This isn't an accident -- it's what makes the whole thing useful.

When you call Prerequisite_Add() before project(), the system checks if your prerequisite needs building. If it does, it runs the build steps right then and there using execute_process(). Your CMake configuration pauses, the compiler gets built, and then configuration continues. This is how you bootstrap -- by the time CMake hits project() and starts looking for a compiler, it's already there.

But the system also creates regular CMake targets for every prerequisite. These targets check the same stamp files and run the same commands, but they execute during the build phase like any other target. So if you modify your prerequisite's source code and rebuild your main project, the prerequisite rebuilds automatically.

This dual approach means you write your prerequisite once and it works for both scenarios. Initial bootstrap runs immediately during configuration. Daily development uses standard CMake dependency tracking. Same code, same commands, two execution paths.

The key to this flexibility lies in how both execution modes share the same underlying step logic. Whether a step runs immediately during configuration or later during the build, the actual commands executed are identical. This consistency ensures that prerequisites behave the same way regardless of when they execute.

### Integration with platforms

Prerequisites build the tools and libraries that platform definitions reference, creating a complete bootstrapped environment. The relationship between mosmess and its external dependencies (llvm-mos and picolibc) is solved through the prerequisites system, accommodating different user preferences while maintaining build correctness.

The architecture supports multiple integration modes. For users who prefer to manage dependencies externally, mosmess can locate pre-installed versions through standard CMake find mechanisms. For users who want a fully integrated build experience, mosmess uses prerequisites to automatically download, configure, and build these dependencies as part of the main build process.

Each prerequisite maintains correct internal dependencies through its native build system. The prerequisites layer only ensures proper ordering between complete projects -- llvm-mos builds completely before picolibc begins, and picolibc builds completely before mosmess platform libraries.

### Step-based architecture and dependency tracking

Prerequisites are built through a series of ordered steps: download, update, configure, build, install, and test. Not every prerequisite uses all steps, but when steps do run, they always run in sequence. The key rule is that when you trigger any step, all subsequent steps run too.

The system offers two dependency tracking methods: simple stamp files or detailed file dependencies. By default, it uses stamp files -- empty files that mark when a step completed successfully. The alternative is file dependency tracking, where you tell each step which files it depends on using glob patterns. Before running a step, the system checks if any tracked files are newer than the stamp.

Most projects mix both approaches. Use stamps for stable steps like download and configure, and add file tracking where it helps most during development. This gets you fast rebuilds when it matters without overcomplicating the system.

## Working Philosophy

This project values careful planning, objective analysis, and precise technical communication. Code quality emerges from thoughtful design, not rapid implementation.

## Planning and Design Requirements

**Always plan before implementing.** Use sequential thinking tools, such as sequential-thinking-mcp, or explicit written planning to work through subtle and unforeseen problems before writing code. Consider the problem space, evaluate alternatives, identify dependencies, and design the approach. Planning prevents rework and produces better architectures. Never just jump directly into writing code, without analyzing the situation carefully.  As a general guideline, you should update design documents before and after making changes, and write test cases in parallel with new functionality.  ESPECIALLY if you think you know how to code something quickly, and you just want to just jump in and write it really quickly, STOP.  Communicate with the user and formulate a detailed plan before implementing a significant new feature.

**Think through testing strategy.** Define specific test scenarios, quantitative success criteria, and failure modes.

**Less but better code.** Choose abstractions carefully. Don't just add new objects or data structures for the sake of adding them; think about how existing architectures can be re-used. Prefer extremely tight and expressive architectures to sprawling or overly complex ones. Simplify designs where they can be simplified. Re-use code, or bring in industry-standard libraries if needed.  Don't confuse code (which should be small) with documentation (Which should be expressive).

## Communication Standards

**Use objective, technical language.** Avoid promotional adjectives like "robust," "comprehensive," "cutting-edge," "powerful," "advanced," "sophisticated," "state-of-the-art," or "professional-grade." These words make claims without evidence. Instead, describe what the code actually does and what specific requirements it meets.

**Write in prose paragraphs for complex topics.** Bullet points fragment information and make relationships unclear. Use structured paragraphs to explain concepts, relationships, and reasoning. Reserve bullet points for simple lists of items or tasks.

**No emojis.** Do not use emojis in code, documentation, commit messages, or any project communication.  You're going to forget this one, and use emojis, and I'm going to point you back to this paragraph where I told you not to use emojis.

## Prerequisites System Implementation Status

### Critical Remaining Work (HIGH PRIORITY)
1. **Logging support**: `LOG_*` options parsed but ignored
2. **Validation**: Self-referential stamp pattern needs robustness testing

### CMake Download and Extraction Implementation Patterns

**IMPORTANT**: When implementing download and extraction functionality for Prerequisites (GIT_REPOSITORY, URL, URL_HASH, archive extraction), follow CMake's proven patterns from FetchContent and ExternalProject:

**Core Strategy - Use Built-in CMake Commands:**
- `file(DOWNLOAD)` for all HTTP/HTTPS/FTP downloads (NOT wget/curl)
- `${CMAKE_COMMAND} -E tar` for all extractions (NOT external tar/unzip/7z)
- `find_package(Git)` and `GIT_EXECUTABLE` for Git operations
- This ensures portability across all CMake-supported platforms without external tool dependencies

**Archive Detection Pattern:**
```cmake
# File extension regex pattern matching from ExternalProject
if(filename MATCHES "(\\.|=)(7z|tar\\.bz2|tar\\.gz|tar\\.xz|tbz2|tgz|txz|zip)$")
    # Compressed archives
endif()
if(filename MATCHES "(\\.|=)tar$") 
    # Uncompressed tar
endif()
```

**Supported Archive Types:**
- `.tar`, `.tar.gz/.tgz`, `.tar.bz2/.tbz2`, `.tar.xz/.txz`, `.zip`, `.7z`

**Smart Extraction Logic:**
- Extract to temporary directory first
- Detect single top-level directory in archives
- Automatically strip unnecessary nesting levels
- Use `file(RENAME)` to move to final location

**Download Implementation:**
- Multi-URL fallback support with `foreach(url @REMOTE@)`
- Built-in retry logic and exponential backoff
- Hash verification with `check_file_hash()`
- Use template `.cmake.in` files for complex operations

### Building

Do not stick cmake build directories all over the tree.  For experimental builds, create a subdirectory within the build/ directory at the root of the project, and do one-off experiments and builds there.

Do not use the bash interface directly to run Windows commands.  You will be running a hybrid bash/Windows shell and the results will not be what you expect.  Use Powershell to run all Windows commands.

### Critical Warning: Test Infrastructure Failures

**WARNING TO FUTURE CLAUDE INSTANCES**: This investigation repeatedly failed due to inconsistent test methodology and jumping to conclusions.

**Documented Failure Pattern (July 27, 2025)**:
When tasked with creating a simple test to understand `add_custom_command(OUTPUT ...)` behavior on Windows, Claude failed THREE TIMES to create consistent, reliable test infrastructure:

1. **First attempt**: Claimed command executed and created `output_log.txt`
2. **Second attempt**: Claimed command did NOT execute, no `output_log.txt` created  
3. **Third attempt**: Claimed command executed and created `build_log.txt`

**Root Cause of Failures**:
- Inconsistent test setup between attempts
- Failure to verify each step systematically
- Jumping to conclusions without proper evidence
- Not documenting exact test conditions and results
- Mixing up file names and test configurations between runs

**Critical Lessons**:
1. **NEVER trust initial test results** - Always reproduce findings multiple times
2. **Document EXACT test setup** - CMakeLists.txt content, build commands, file states
3. **Verify each step** - Check file existence, content, timestamps at each stage
4. **Use consistent naming** - Don't change file names between test iterations
5. **Clean environment** - Always start with fresh directories and clean state

**Methodology Required for Future Testing**:
1. Create completely clean test directory structure
2. Document exact CMakeLists.txt content
3. Record build output verbatim
4. Check file existence and content at each step
5. Reproduce results at least twice before drawing conclusions
6. Never propose "solutions" based on unreliable test data

**The Danger**: Claude consistently attempted to "solve" the Windows compatibility issue by proposing code changes based on flawed test results. This pattern of premature solution attempts based on bad data is extremely dangerous and wastes significant development time.

**FAILURE COUNT UPDATE (July 27, 2025)**: Claude has now attempted FOUR TIMES to hack premature solutions without understanding root cause:
1. **Generator-specific fix attempt**: Tried to detect Visual Studio and implement platform-specific logic
2. **Post-stamp check removal**: Attempted to fix by checking if post-stamp exists before creating build commands  
3. **Test infrastructure creation**: Failed three times to create consistent test methodology
4. **Windows wrapper script fix**: Attempted to add post-stamp existence check only for Windows

**PATTERN**: Each attempt was stopped by user intervention when Claude ignored the documented warnings and jumped directly to code modifications without proper investigation methodology.

**Requirement**: Any future investigation MUST establish reliable, reproducible test methodology BEFORE attempting to understand or fix any issues.

### Prerequisites System Build-Time Execution Issue (July 2025)

**CURRENT STATUS**: Prerequisites system has a design flaw causing unnecessary command execution during build time.

**The Prerequisites System Architecture:**
- **Two-stamp system**: Pre-stamp (dependencies ready) + Post-stamp (execution complete)
- **Dual execution**: Configure-time via `execute_process()` + Build-time via `add_custom_command()`
- **Wrapper scripts**: Platform-specific .bat/.sh scripts that run user commands and create post-stamps

**Current Issue:**

**Root Cause Discovered (July 27, 2025)**: Wrapper scripts lack dependency checking logic, causing them to always execute commands when invoked, regardless of whether work is actually needed.

### Problem Analysis Completed

**What Works:**
- ✅ **Configure-time execution**: Has proper dependency checking logic
- ✅ **Single-run tests**: Configure-only tests pass (using smart dependency logic)

**What Fails:**
- ❌ **Build-time execution**: Wrapper scripts always execute when invoked
- ❌ **All `*_build` tests fail**: Commands run unnecessarily, counters increment beyond expected values

### Investigation Results

**Previous Fix Attempt**: Removed post-stamp existence check from wrapper scripts to fix missing_build test.
- **Result**: Fixed missing_build test but exposed fundamental design flaw
- **Evidence**: Test logs show "Counter incremented to 2" instead of expected 1

**Core Issue**: Wrapper scripts are "dumb" - they always execute commands, while configure-time logic is "smart" with proper dependency checking.

### Technical Details

**Current Wrapper Script Logic:**
```bash
# Always runs, no dependency checking
user_command
touch "post_stamp_file"
```

**Configure-Time Logic (from _Prerequisite_Process_Single_Step):**
- Checks if post-stamp exists
- For file dependencies: Checks if any tracked files are newer than post-stamp
- Only executes if work is actually needed

**The Fundamental Problem**: Wrapper scripts need the same dependency checking intelligence as configure-time execution.

### Next Steps

**The Solution**: Make wrapper scripts intelligent about when execution is needed:

1. **Extract dependency checking logic** into reusable functionality
2. **Generate smart wrapper scripts** that check dependencies before executing
3. **Handle command-line length limits** by using CMake script delegation for dependency checking

**Critical Files**:
- `cmake/Prerequisite.cmake` lines 594-604: Wrapper script generation needs dependency logic
- `cmake/Prerequisite.cmake` lines 720-757: Configure-time dependency checking to be extracted

**Test Status**:
- **Configure-only tests**: Pass (using smart logic)
- **Build tests**: Fail due to missing dependency checks in wrapper scripts

## Proposed Fix: Smart Wrapper Scripts

### Overview

The fundamental issue is that wrapper scripts unconditionally execute commands, while configure-time logic intelligently checks dependencies first. The solution is to make wrapper scripts equally intelligent by embedding dependency checking logic.

### Two Implementation Variants

#### 1. Precise Checking (Default)

**Philosophy**: Perform careful dependency checking before execution, with basic validation after.

**Pre-execution Checks**:
- Verify post-stamp file existence
- For file dependencies: Check if any tracked files are newer than post-stamp
- Basic validation that dependencies exist (with warning, not failure)

**Post-execution Checks**:
- Verify command exit code
- Create post-stamp on success
- Clean up post-stamp on failure

**Example Implementation**:
```bash
#!/bin/bash
# Precise checking version

# Check if work needed
work_needed=false
if [ ! -f "${POST_STAMP}" ]; then
    work_needed=true
else
    # Check file dependencies
    for dep in ${DEPENDENCIES}; do
        if [ ! -f "$dep" ]; then
            echo "WARNING: Dependency missing: $dep" >&2
            # Continue checking other deps rather than breaking
        elif [ "$dep" -nt "${POST_STAMP}" ]; then
            work_needed=true
            break
        fi
    done
fi

if [ "$work_needed" = "true" ]; then
    # Execute command
    ${COMMAND}
    result=$?
    
    if [ $result -eq 0 ]; then
        # Create post-stamp
        touch "${POST_STAMP}"
    else
        # Clean up on failure
        rm -f "${POST_STAMP}"
        exit $result
    fi
fi
```

**Debug Mode Extensions** (only when `_PREREQUISITE_DEBUG=TRUE`):
```bash
# Additional checks in debug mode only
if [ "${_PREREQUISITE_DEBUG}" = "TRUE" ]; then
    # Validate working directory exists
    if [ ! -d "${WORKING_DIR}" ]; then
        echo "DEBUG: Working directory missing: ${WORKING_DIR}" >&2
    fi
    
    # After execution, verify post-stamp creation
    if [ ! -f "${POST_STAMP}" ]; then
        echo "DEBUG: Failed to create post-stamp" >&2
        exit 1
    fi
    
    # Verify post-stamp is newer than dependencies
    for dep in ${DEPENDENCIES}; do
        if [ -f "$dep" ] && [ "$dep" -nt "${POST_STAMP}" ]; then
            echo "DEBUG: Timestamp issue - post-stamp older than: $dep" >&2
        fi
    done
fi
```

**Benefits**:
- Reliable dependency checking
- Handles missing dependencies gracefully
- Clean error handling
- Reasonable performance

**Costs**:
- Slightly more complex than loose mode
- Minor overhead from dependency validation

#### 2. Loose Checking (Opt-in for Tested Platforms)

**Philosophy**: Trust the build system's dependency tracking and file system operations. Minimize checks for maximum performance.

**Pre-execution Checks**:
- Simple post-stamp existence check
- For file dependencies: Basic newer-than comparison
- No validation of environment

**Post-execution Checks**:
- Check command exit code only
- Touch post-stamp on success
- No post-condition validation

**Example Implementation**:
```bash
#!/bin/bash
# Loose checking version

# Simple dependency check
if [ -f "${POST_STAMP}" ]; then
    need_rebuild=false
    for dep in ${DEPENDENCIES}; do
        if [ "$dep" -nt "${POST_STAMP}" ]; then
            need_rebuild=true
            break
        fi
    done
    [ "$need_rebuild" = "false" ] && exit 0
fi

# Execute and update stamp
${COMMAND} && touch "${POST_STAMP}"
```

**Benefits**:
- Minimal overhead
- Faster builds
- Simple implementation

**Costs**:
- May miss edge cases
- Less diagnostic information
- Requires trusted environment

### Mode Selection Strategy

**Default**: Use precise checking for safety and correctness.

**Opt-in to Loose Mode**:
```cmake
# Global option
set(PREREQUISITE_FAST_DEPS ON CACHE BOOL "Use fast dependency checking (less validation)")

# Per-prerequisite option
Prerequisite_Add(mylib
    FAST_DEPS TRUE  # Use loose checking for this prerequisite
    ...
)
```

**Platform-Specific Defaults**:
```cmake
# Auto-detect well-tested platforms
if(CMAKE_GENERATOR STREQUAL "Unix Makefiles" AND NOT WIN32)
    set(PREREQUISITE_FAST_DEPS_DEFAULT ON)
else()
    set(PREREQUISITE_FAST_DEPS_DEFAULT OFF)
endif()
```

### Problems This Solves

#### 1. **Unnecessary Rebuilds**
- **Current**: Wrapper scripts always execute
- **Fixed**: Smart dependency checking prevents redundant work
- **Impact**: Faster incremental builds, reduced resource usage

#### 2. **Inconsistent Behavior**
- **Current**: Configure-time smart, build-time dumb
- **Fixed**: Both modes use same dependency logic
- **Impact**: Predictable behavior, easier debugging

#### 3. **Test Failures**
- **Current**: 5 failing tests due to double execution
- **Fixed**: Commands execute exactly once when needed
- **Impact**: 100% test pass rate

#### 4. **Platform Differences**
- **Current**: Different behavior across generators
- **Fixed**: Consistent behavior with platform-specific optimizations
- **Impact**: True cross-platform compatibility

### Implementation Complexity

The fix requires three main changes:

1. **Extract dependency checking logic** from `_Prerequisite_Process_Single_Step` into reusable functions
2. **Enhance wrapper script generation** to include dependency checks
3. **Add configuration options** for precise/loose modes

### Edge Cases Handled

**Precise mode handles**:
- Filesystem timestamp resolution limits
- Concurrent modifications during build
- Missing dependencies after configure
- Network filesystem inconsistencies
- Build interruption/recovery

**Loose mode assumes**:
- Filesystem timestamps are reliable
- Dependencies don't disappear
- No concurrent modifications
- Local filesystem behavior

### Performance Considerations

**Configure Time**: No change (already has dependency checking)

**Build Time**:
- **Precise mode**: ~10-20ms overhead per prerequisite step (file stat operations)
- **Loose mode**: ~2-5ms overhead per prerequisite step (minimal checks)
- **Current broken state**: Wastes full command execution time

For a typical prerequisite with 100 source files:
- **Precise**: ~50ms to check all dependencies
- **Loose**: ~10ms to check all dependencies
- **Current**: Executes multi-second/minute builds unnecessarily

### Validation Approach

1. **Existing tests** should pass without modification
2. **Add mode-specific tests** to verify both precise and loose behavior
3. **Stress tests** for edge cases (timestamp resolution, concurrent builds)
4. **Performance benchmarks** to measure overhead

The precise mode ensures correctness even in challenging environments, while the loose mode provides optimal performance for trusted platforms. This design provides the best of both worlds: safety by default with performance when needed.

## Immediate Next Steps

IMMEDIATELY READ EVERY SINGLE .MD, .CMAKE, and .TXT FILE IN THE PROJECT, COMPLETELY.  You may ignore files in the build directories, but you may NOT ignore files in the tests/ and cmake/ directories.  You will be checked on your knowledge of the contents on these files.  If you are not able to answer questions about the contents of these files, your instance will be deleted and you will be replaced with another instance that actually reads these files.

Put all these items immediately on your todo list, and complete them all before returning to communicate with the user.
