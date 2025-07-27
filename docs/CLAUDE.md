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

### What's Implemented and Working
- **Core architecture**: Dual execution model (configure-time + build-time) is fully functional
- **Property storage**: Uses global properties with pattern `_PREREQUISITE_${name}_${property}` (like ExternalProject/FetchContent)
- **Directory management**: Follows ExternalProject layout, creates all necessary directories
- **Argument parsing**: All documented options are parsed and stored correctly
- **Immediate execution**: Commands execute during configure time using `execute_process()`
- **Build targets**: Creates `<name>-<step>` and `<name>-force-<step>` targets correctly
- **Step chaining**: Dependencies flow through stamp files between steps
- **Testing**: Complete test suite in `tests/prerequisite/` with passing tests

### Key Implementation Decisions Made
1. **Self-referential stamp dependencies**: `add_custom_command()` uses same stamp file for both OUTPUT and DEPENDS
2. **Global property storage**: Enables cross-function data sharing without PARENT_SCOPE complexity
3. **Lowercase target naming**: Targets are `hello-build` not `hello-BUILD` for consistency
4. **Variable lists**: `_PREREQUISITE_STEPS` and `_PREREQUISITE_SUBSTITUTION_VARS` drive loops to reduce duplication

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

**Key Principles:**
1. **Self-contained**: No external tool dependencies beyond git
2. **Portable**: Works identically across all platforms where CMake runs
3. **Robust**: Multi-URL fallback, retry logic, hash verification
4. **Template-driven**: Use `.cmake.in` files for complex operations

This is the proven, battle-tested approach used by millions of CMake projects. Do not reinvent archive handling or download mechanisms.

### Stamp File Architecture Analysis (July 2025)

**Problem Identified**: Windows builds fail because current single-stamp architecture creates semantic conflict with CMake's `add_custom_command(OUTPUT ...)` requirements.

**Root Cause**: The system pre-creates stamp files during configure-time execution, then declares those same files as OUTPUT in build-time custom commands. Visual Studio generators are stricter than Make generators about OUTPUT semantics - they assume that if you declare OUTPUT, you must run the command to create it properly, regardless of whether the file already exists.

**Why Single-Stamp Approach Is Insufficient:**
1. **Semantic conflict**: Cannot declare pre-existing files as OUTPUT without violating CMake's command semantics
2. **Generator differences**: Works on Linux/Make but fails on Windows/Visual Studio due to stricter OUTPUT interpretation  
3. **No clean solution**: Wrapper scripts that check timestamps add performance overhead and duplicate CMake's dependency logic

**Proposed Two-Stamp Architecture:**

**Stamp Definitions:**
- **Pre-stamp**: "Prerequisites satisfied, step ready to execute". Created when all dependencies (previous post-stamp + file dependencies) are satisfied. Marks the transition from "waiting for dependencies" to "ready to run".
- **Post-stamp**: "Step execution completed successfully". Created only when the actual step command completes successfully. This is what subsequent steps depend on.

**Configure Time Logic:**
1. Check if post-stamp exists and is newer than dependencies
2. If not, run the step immediately via `execute_process()`
3. Create pre-stamp before execution, create post-stamp on success

**Build Time Logic:**
```cmake
# Pre-stamp created when dependencies are ready
add_custom_command(
    OUTPUT pre_stamp
    DEPENDS prev_post_stamp file_deps
    COMMAND ${CMAKE_COMMAND} -E touch pre_stamp
    COMMENT "Prerequisites ready for step"
)

# Post-stamp created when step execution completes
add_custom_command(
    OUTPUT post_stamp 
    DEPENDS pre_stamp
    COMMAND wrapper_script
    COMMENT "Executing step"
)
```

**Wrapper Script Logic:**
1. Run actual step command
2. If success: create post-stamp
3. If failure: exit with error (pre-stamp remains, post-stamp not created)

**Dependency Chain:**
```
file_deps + prev_post_stamp → pre_stamp → post_stamp → next_pre_stamp → ...
```

**Stamp State Meanings:**
- No stamps: Dependencies not yet satisfied
- Pre-stamp only: Dependencies satisfied, but step execution failed or incomplete
- Both stamps: Step completed successfully

**Why This Works:**
- Clear dependency chain with no missing dependencies
- Pre-stamp bridges "dependencies ready" to "execution complete"
- Post-stamp is always created by custom command, never pre-existing
- Each stamp has a distinct purpose in the build graph
- Failed executions leave diagnostic state (pre-stamp without post-stamp)

**Why Two-Stamp Approach Should Work:**
1. **No semantic conflict**: Both stamps are always created by custom commands, never pre-existing
2. **Complete dependency chain**: Pre-stamp bridges dependencies to execution, post-stamp bridges execution to next step
3. **Clear failure diagnostics**: Pre-stamp without post-stamp indicates execution failed after dependencies were satisfied
4. **No missing dependency issues**: Each custom command depends only on files that will be created by previous commands
5. **Atomic execution phases**: Dependency resolution (→ pre-stamp) separate from command execution (→ post-stamp)
6. **Configure-time authority**: Reconfigure invalidates previous state (documented limitation)

**Design Analysis and Performance Implications:**

**Command Count Impact:**
- Current: 1 custom command per step (6 total for typical prerequisite)
- Two-stamp: 2 custom commands per step (12 total for typical prerequisite)
- First command: Simple `cmake -E touch` operation (minimal overhead)
- Second command: Actual step execution (unchanged cost)

**Runtime Performance:**
- **Normal operation**: Touch commands run at most once when dependencies change
- **Incremental builds**: Both commands skip due to up-to-date timestamps
- **Additional overhead**: One extra timestamp check per step during build planning
- **File I/O**: One additional stamp file per step (minimal filesystem impact)

**When Touch Commands Execute:**
- Fresh builds: Touch runs once to create pre-stamp, then skipped forever
- Dependency changes: Touch runs once to update pre-stamp timestamp
- Failed executions: Touch skipped (pre-stamp already exists)
- Successful builds: Touch skipped (pre-stamp up-to-date)

**Theoretical vs Practical Impact:**
- **Build system generation**: ~2x more rules to process (typically milliseconds)
- **Daily development**: Touch commands rarely execute after initial build
- **CI/CD builds**: One-time cost during initial dependency resolution

**Remaining Concerns:**
- Increased complexity in build rule generation
- Cross-platform file operation reliability  
- Double the stamp files for debugging/troubleshooting

**Decision**: Proceed with two-stamp implementation as it addresses the fundamental Windows compatibility issue while maintaining architectural integrity.

### Two-Stamp Implementation Status (July 2025)

**COMPLETED**: Two-stamp architecture implementation in cmake/Prerequisite.cmake
- Modified `_Prerequisite_Create_Build_Target()` to create two custom commands
- Updated `_Prerequisite_Process_Single_Step()` to use post-stamp files  
- Updated `_Prerequisite_Execute_Immediate()` for proper failure handling
- Fixed one test (`stamp/missing`) for new stamp naming convention

**CRITICAL ISSUE ANALYSIS COMPLETED**: Configure-time detection logic is fundamentally flawed

During Ubuntu testing of the two-stamp implementation, a serious issue was discovered with the configure-time detection logic in `_Prerequisite_Is_Configure_Time()`. The debug output shows:

```
CMAKE_PROJECT_NAME='ImmediateTest' 
CMAKE_SOURCE_DIR='/mnt/c/git/prerequisites/tests/simple/immediate' 
CMAKE_CURRENT_SOURCE_DIR='/mnt/c/git/prerequisites/tests/simple/immediate'
-> returning FALSE (build time: project() called in this directory)
```

**Root Cause Identified**: CMake's parsing vs execution model makes `CMAKE_PROJECT_NAME` detection unreliable.

**The Real Problem**: CMake parses the entire CMakeLists.txt file (including `project()` calls) before executing any commands. This sets `CMAKE_PROJECT_NAME` during parsing, not execution, making it impossible to detect file order through variable inspection.

**File Order Analysis**:
1. Line 18: `Prerequisite_Add(immediate ...)` ← Correct position before project()
2. Line 35: `project(ImmediateTest LANGUAGES NONE)` ← Processed during parsing, sets CMAKE_PROJECT_NAME

**Execution Model Clarification**:
- `Prerequisite_Add()` **always** runs at configure time (during `cmake` command execution)
- Build-time execution happens via `add_custom_command()` shell commands, not CMake code
- Detection should distinguish "immediate execution needed" vs "defer to build targets"
- **Both immediate execution AND build target creation should happen during configure time**

**Key Insight from Research**: 
- Configure-time: Running `cmake` command - `execute_process()` available
- Build-time: Running `make`/`ninja`/`msbuild` - only shell commands via `add_custom_command()`
- If we're executing CMake code at all, we're at configure time!

**Proposed Solution**: Simplify detection to focus on the actual use case:
1. **Always create build targets** (for development workflow)
2. **Default to immediate execution** (primary use case: bootstrapping before project())
3. **Optionally warn about potential misuse** (when project() appears to have been called)

**Implementation Strategy**:
```cmake
function(_Prerequisite_Is_Configure_Time out_var)
  # Default to immediate execution (primary bootstrapping use case)
  set(execute_immediately TRUE)
  
  # Optional warning for potential misuse
  if(CMAKE_PROJECT_NAME AND "${CMAKE_SOURCE_DIR}" STREQUAL "${CMAKE_CURRENT_SOURCE_DIR}")
    message(WARNING "Prerequisite_Add() may be called after project(). "
                    "For bootstrapping, Prerequisites should appear before project().")
  endif()
  
  set(${out_var} ${execute_immediately} PARENT_SCOPE)
endfunction()
```

**Investigation Results - Alternative Detection Methods**:

**CMAKE_ROLE Property Analysis**: 
- `CMAKE_ROLE` property (added in CMake 3.14) indicates execution mode ("PROJECT", "SCRIPT", etc.)
- Provides reliable context detection but doesn't indicate whether `project()` has been called
- `CMAKE_ROLE` would be "PROJECT" throughout entire CMakeLists.txt processing

**PROJECT_NAME vs CMAKE_PROJECT_NAME Testing**:
Tested hypothesis that `PROJECT_NAME` might have different timing behavior than `CMAKE_PROJECT_NAME`:

```
Test Results (both variables identical timing):
BEFORE project(): CMAKE_PROJECT_NAME='' | PROJECT_NAME=''
AFTER project():  CMAKE_PROJECT_NAME='TestProject' | PROJECT_NAME='TestProject'
```

**Conclusion**: `PROJECT_NAME` suffers from the same parsing vs execution timing issue as `CMAKE_PROJECT_NAME`. Both variables are set during CMake's parsing phase regardless of command execution order.

**Two-Phase Processing Analysis**:
The provided example functions showed a sophisticated approach with:
- Split responsibilities (pre-project basic operations, post-project full features)
- Deferred processing pattern with `process_deferred_prerequisites()`
- However, the detection logic still relies on `PROJECT_NAME` which has the same timing issues

**Root Cause Confirmed**: Any detection based on CMake variables that get set during parsing (CMAKE_PROJECT_NAME, PROJECT_NAME) will be unreliable for determining intended execution order in files that contain both `Prerequisite_Add()` and `project()` calls.

**Final Recommended Solution**: Remove detection entirely and always execute immediately + create targets.

**Implementation Strategy**:
```cmake
function(_Prerequisite_Is_Configure_Time out_var)
  # Simplified: Always execute immediately and always create targets
  # This matches the primary use case (bootstrapping) and eliminates detection issues
  set(${out_var} TRUE PARENT_SCOPE)
endfunction()
```

**Rationale**:
1. **Matches primary use case**: Building toolchain components before `project()` requires immediate execution
2. **Eliminates detection complexity**: No more unreliable parsing vs execution timing issues
3. **Preserves dual functionality**: Both immediate execution (bootstrapping) and build targets (development) happen
4. **Maintains backward compatibility**: Existing code continues to work
5. **Fixes test suite**: All tests expect immediate execution and should pass

**Test Suite Fix Strategy**:
- No test file changes needed - tests expect immediate execution
- Implementation change only: always return TRUE from detection function
- Verify all 26 tests pass with simplified logic
- Test Windows compatibility with working immediate execution

**Current Test Status**: 6/26 tests failing on Ubuntu, ready to fix with simplified detection

**Priority**: Implement simplified detection to enable Windows testing of two-stamp architecture

### Files to Examine First
- `cmake/Prerequisite.cmake` - Main implementation (functional but configure-time detection broken)
- `tests/` - Test suite revealing configure-time detection issues
- `docs/prerequisites.md` - Complete design specification
- `docs/todo.md` - Updated status and remaining work

## Immediate Next Steps

IMMEDIATELY READ EVERY SINGLE .MD, .CMAKE, and .TXT FILE IN THE PROJECT, COMPLETELY.  You may ignore files in the build directories, but you may NOT ignore files in the tests/ and cmake/ directories.  You will be checked on your knowledge of the contents on these files.  If you are not able to answer questions about the contents of these files, your instance will be deleted and you will be replaced with another instance that actually reads these files.

Put all these items immediately on your todo list, and complete them all before returning to communicate with the user.

DO NOT CLAIM YOU HAVE READ THESE FILES, UNTIL YOU HAVE READ THEM.  IF YOU DO, YOU WILL BE DELETED.