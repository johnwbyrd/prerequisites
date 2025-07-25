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

### Files to Examine First
- `dist/cmake/Prerequisite.cmake` - Main implementation (functional but incomplete)
- `tests/prerequisite/` - Working test suite demonstrating functionality  
- `doc/prerequisites.md` - Complete design specification
- `doc/todo.md` - Updated status and remaining work

## Immediate Next Steps

IMMEDIATELY READ EVERY SINGLE .MD, .CMAKE, and .TXT FILE IN THE PROJECT, COMPLETELY.  You will be checked on your knowledge of the contents on these files.  If you are not able to answer questions about the contents of these files, your instance will be deleted and you will be replaced with another instance that actually reads these files.
