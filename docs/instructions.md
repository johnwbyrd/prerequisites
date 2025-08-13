## Prerequisites System

### The bootstrapping problem

The CMake prerequisites system solves the fundamental problem of building compilers and libraries before CMake's project() command can detect them. This system is essential where custom toolchains must often be built from source.

Traditional CMake projects assume that compilers and essential libraries already exist when configuration begins. The project() statement triggers compiler detection, feature tests, and library searches. But this creates ordering challenges when you need to build the very tools that CMake is about to look for. CMake needs these tools to configure your project, but you need CMake to build the tools.

The prerequisites system breaks this deadlock by operating before the project() command runs. It can build your dependencies immediately during configuration so they're ready when project() executes, while also creating normal CMake targets for incremental rebuilds later.

### Single-Stamp Execution Model

The prerequisites system uses a single-stamp architecture where each step has exactly one stamp file that marks successful completion. This stamp file serves as both:
1. The output of the step's execution
2. The dependency marker for subsequent steps

The system operates in both configure time and build time modes with identical behavior:

1. **Configure Time**:
   - Checks dependencies and executes steps if needed
   - Creates stamp file only after successful execution
   - Uses execute_process() for immediate execution

2. **Build Time**:
   - Creates CMake targets that check the same stamp files
   - Executes same commands if stamps are missing or outdated
   - Maintains identical behavior to configure-time execution

The single-stamp design provides:
- Simpler implementation with fewer files
- Clearer dependency tracking
- More reliable rebuild detection

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

**Documented Failure Pattern**:
When tasked with creating a simple test to understand `add_custom_command(OUTPUT ...)` behavior on Windows, Claude failed FOUR TIMES to create consistent, reliable test infrastructure:

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

Each attempt was stopped by user intervention when Claude ignored the documented warnings and jumped directly to code modifications without proper investigation methodology.

**Requirement**: Any future investigation MUST establish reliable, reproducible test methodology BEFORE attempting to understand or fix any issues.

### Current Diagnostic Challenge

**The Problem**: In clean build scenarios, configure-time commands are not executing when they should.

**Evidence:**
- Counter files show 0 executions when tests expect 1
- Post-stamp files exist prematurely in clean builds
- Wrapper scripts correctly detect existing stamps and skip execution

**Hypothesis**: Dual execution path interference
- Configure-time may still use old `_Prerequisite_Execute_Immediate` path
- Build-time uses new smart wrapper scripts
- Timing/coordination issues between the two paths

### Reconfigure Behavior Design Decision

**Issue Identified**: The Prerequisites system has inconsistent reconfigure behavior. On initial configure, commands execute regardless of existing stamps (clean build authority). On reconfigure, commands respect existing stamps and may skip execution (performance optimization).

**Design Decision - Hybrid Approach**:

**Default Behavior**: Clean stamps on reconfigure (configure is authoritative)
- Most prerequisites are small/fast, so clean-by-default is acceptable
- Provides simple, predictable behavior
- Maintains "configure is authoritative" principle

**Per-Prerequisite Override**: Allow `RECONFIGURE_BEHAVIOR RESPECT_STAMPS` option
- Large expensive prerequisites (compilers, toolchains) can opt into performance optimization
- Users explicitly choose when performance matters more than simplicity

**Emergency Override**: Environment variable `PREREQUISITE_FORCE_CLEAN=1`
- Provides escape hatch when stamp-respecting behavior causes issues
- Allows users to force clean behavior globally when needed

**Implementation Approach**:
```cmake
Prerequisite_Add(llvm
    RECONFIGURE_BEHAVIOR RESPECT_STAMPS  # Keep expensive builds
    # ... other options
)

Prerequisite_Add(my_small_tool  
    # Uses default CLEAN_STAMPS behavior - simple and predictable
    # ... other options  
)
```

This design provides the best of both worlds: simple default behavior that "just works" with performance optimization available where needed.

## Immediate Next Steps

IMMEDIATELY READ EVERY SINGLE .MD, .CMAKE, and .TXT FILE IN THE PROJECT, COMPLETELY.  You may ignore files in the build directories, but you may NOT ignore files in the tests/ and cmake/ directories.  You will be checked on your knowledge of the contents on these files.  If you are not able to answer questions about the contents of these files, your instance will be deleted and you will be replaced with another instance that actually reads these files.

Put all these items immediately on your todo list, and complete them all before returning to communicate with the user.
