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

### Prerequisites System Architecture and Windows Test Failures (July 2025)

**CRITICAL UNDERSTANDING FOR FUTURE CLAUDE INSTANCES:**

The Prerequisites system is designed to solve the bootstrapping problem: building tools (like compilers) during CMake configuration BEFORE the `project()` command runs, so those tools are available when `project()` tries to find them.

**The Intended Behavior:**
1. **Configure time**: Commands run immediately via `execute_process()` to bootstrap tools before `project()`
2. **Build time**: Same commands should be skipped because stamps exist from configure-time execution
3. **Development workflow**: Build targets exist for incremental rebuilds when source files change

**Two-Stamp Architecture (ALREADY IMPLEMENTED):**

The code already implements a two-stamp system:
- **Pre-stamp**: `${name}-${step}-pre` - Created when dependencies are satisfied, ready to execute
- **Post-stamp**: `${name}-${step}-post` - Created when step execution completes successfully

**CRITICAL: The two-stamp architecture is NOT about fixing OUTPUT semantics. It's about proper dependency tracking in the build system.**

**How It Should Work:**
1. **Configure time**: If post-stamp missing or out-of-date, run command and create post-stamp
2. **Build time**: Custom commands declare both stamps as OUTPUT, but skip execution if stamps exist and are up-to-date
3. **Visual Studio should respect existing OUTPUT files** - if it doesn't, that indicates a different problem

## ROOT CAUSE OF WINDOWS TEST FAILURES (JULY 2025)

## CMake Script Auto-Execution Bug Discovery (July 2025)

**CRITICAL DISCOVERY**: The Windows test failures are NOT caused by the Prerequisites system executing commands twice. The system works correctly - commands execute once at configure time and are properly skipped at build time via the wrapper.

**THE ACTUAL PROBLEM**: CMake has an undocumented behavior where it automatically executes any `.cmake` file it encounters as a command-line argument during script processing.

### How This Was Discovered

1. **Initial symptoms**: Tests showed `increment_counter.cmake` being called with wrong arguments, causing "Usage:" errors
2. **Wrapper analysis**: Debug output proved the wrapper correctly skips execution when post-stamps exist
3. **Argument tracing**: Added debug output to `increment_counter.cmake` showing it receives 9 arguments instead of expected 4
4. **Key insight**: The script receives the same arguments as the wrapper (CMAKE_ARGV0-8), not its own arguments
5. **Definitive proof**: Replaced `increment_counter.cmake` with `test_data.txt` in command arguments, which caused CMake parse error: "Expected '(', got identifier with text 'is'"

### The Root Cause

When the wrapper is called with these arguments:
```
cmake -P wrapper.cmake POST_STAMP WORKING_DIR cmake -P increment_counter.cmake COUNTER_FILE
```

CMake processes `increment_counter.cmake` at argument position CMAKE_ARGV7 and **automatically executes it as a script file** during argument parsing, before the wrapper even runs its logic.

### Evidence

- **Wrapper debug**: Shows correct skipping behavior ("EXISTS=YES", "Skipping - post-stamp exists")
- **Script debug**: Shows `increment_counter.cmake` called with wrapper's 9 arguments, not its own 4
- **Test substitution**: Replacing `.cmake` with `.txt` file causes CMake parse error, proving auto-execution

### Command Prepend/Append Solution

**New approach**: Instead of wrapper scripts, modify user commands by prepending stamp checks and appending stamp creation:

**Windows:**
```batch
if not exist "post_stamp_file" ( user_original_command && echo. > "post_stamp_file" )
```

**Unix:**
```bash
[ ! -f "stamp_file" ] && ( user_original_command && touch "post_stamp_file" )
```

**Why this works**:
- No intermediate script execution that could mangle user commands
- User command stays exactly as written - no argument parsing or re-execution
- Native shell handles all complexity (quotes, spaces, etc.)
- Single command line passed directly to build system

**Acceptable limitations**: 
- Single command per step (no semicolon-separated sequences)
- Predictable success/failure behavior
- No complex shell control structures or error handling with `||`
- No background processes

**Rationale for limitations**: Prerequisites is designed for typical build tool invocations (`cmake`, `make`, `configure`, etc.) which are single executables with parameters. Users needing complex shell logic can create wrapper scripts.

**Why this solution is essential**: Without preventing double execution, Prerequisites is fundamentally broken for real-world use. The test failures revealed this isn't just a test issue - it's a core system requirement that commands execute exactly once.

## Windows Double Execution Fix Implementation (July 2025)

### Problem Analysis Completed

The Windows test failures were caused by CMake's `add_custom_command()` semantics conflicting with the single-stamp architecture. When declaring a pre-existing file as OUTPUT, Visual Studio generators reject it, causing commands to execute at both configure time AND build time.

### Solution: Wrapper Script Generation

**Implementation Status**: PARTIALLY IMPLEMENTED - Core wrapper script generation working, command parsing issue identified.

**Approach**: Generate platform-specific wrapper scripts at configure time that handle stamp checking and command execution:

1. **Script Location**: `${CMAKE_BINARY_DIR}/prerequisite-wrappers/${name}/${step}-wrapper.bat` (Windows) or `.sh` (Unix)

2. **Script Content (Windows)**:
```batch
@echo off
if exist "stamp_file" exit /b 0
user_command_line
if %errorlevel% neq 0 exit /b %errorlevel%
echo. > "stamp_file"
```

3. **Script Content (Unix)**:
```bash
#!/bin/bash
if [ -f "stamp_file" ]; then exit 0; fi
user_command_line
if [ $? -ne 0 ]; then exit $?; fi
touch "stamp_file"
```

4. **CMake Integration**: Replace user command with `cmd /c script.bat` or `bash script.sh`

### Implementation Functions Added

**`_Prerequisite_Create_Wrapper_Script()`**: Creates platform-specific wrapper scripts
- **Parameters**: `name`, `step`, `command_list`, `post_stamp_file`, `out_execute_command`
- **Functionality**: Generates wrapper script with stamp checking logic
- **Output**: Returns execute command for `add_custom_command()`

**Integration Point**: Modified `_Prerequisite_Create_Build_Target()` to use wrapper scripts instead of direct command execution.

### Current Status: 54% Test Pass Rate

**Working**: 
- Wrapper script generation successful
- Clean vcxproj output shows `cmd /c script.bat` execution
- Scripts contain correct stamp checking logic

**Issue Identified**: Command parsing error - `/c: /c: Is a directory`
- Root cause: CMake list `cmd /c` being interpreted as separate command + argument
- Fix needed: Proper command list construction for `add_custom_command()`

### Validation Results

**vcxproj Analysis**: Generated Visual Studio project files now show clean command execution:
```xml
cmd /c C:/git/prerequisites/build/tests/stamp/incremental/prerequisite-wrappers/incremental/DOWNLOAD-wrapper.bat
```

This is a significant improvement over the previous mangled quoted strings.

**Script Verification**: Generated wrapper scripts contain correct logic:
- Stamp existence checking
- Error propagation
- Conditional execution
- Cross-platform compatibility

### Next Implementation Phase

1. **Fix command list construction** in `_Prerequisite_Create_Wrapper_Script()`
2. **Validate Unix script execution** with `bash script.sh`
3. **Complete test suite validation** targeting 100% pass rate

## Immediate Next Steps

IMMEDIATELY READ EVERY SINGLE .MD, .CMAKE, and .TXT FILE IN THE PROJECT, COMPLETELY.  You may ignore files in the build directories, but you may NOT ignore files in the tests/ and cmake/ directories.  You will be checked on your knowledge of the contents on these files.  If you are not able to answer questions about the contents of these files, your instance will be deleted and you will be replaced with another instance that actually reads these files.

Put all these items immediately on your todo list, and complete them all before returning to communicate with the user.
