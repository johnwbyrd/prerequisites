## Prerequisites System

### The bootstrapping problem

A critical component of mosmess is the CMake prerequisites system, which solves the fundamental problem of building compilers and libraries before CMake's project() command can detect them. This system is essential for the MOS ecosystem where custom toolchains must often be built from source.

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

## Technical Implementation Principles

### CMake property propagation mechanics

When debugging property propagation issues, remember that CMake provides excellent introspection capabilities. You can examine the final property values on any target to understand how inheritance chains resolved. This makes the system much more debuggable than custom inheritance implementations.

Do not assume that property propagation always works as expected. CMake's property system is powerful but has edge cases and limitations. Always test inheritance chains thoroughly and provide clear error messages when property propagation fails.

Remember that different types of properties propagate differently. Include directories and compile definitions propagate transitively, but some properties do not. Link libraries propagate but with complex rules about visibility and ordering. Understanding these nuances is crucial for implementing reliable platform inheritance.

### Build system boundary respect

Be extremely careful about respecting build system boundaries. CMake should not try to directly manage Meson builds, Meson should not attempt to parse CMake files, and so on. Each build system should operate within its domain and coordinate with others through well-defined interfaces.

The prerequisites system works because it operates at the coordination level, not the implementation level. It invokes build systems as black boxes and consumes their outputs, rather than trying to understand their internals. This approach maintains clean separation of concerns and avoids fragile cross-build-system dependencies.

When implementing cross-project dependencies through prerequisites, focus on coarse-grained ordering constraints. Prerequisites handle entire projects as units -- one project builds completely before another begins. Each prerequisite maintains correct internal dependencies through its native build system, while the prerequisites layer ensures proper ordering between complete projects.

### Cross-project dependency coordination

The dependency integration challenge requires careful attention to build system boundaries and dependency propagation. Each integration mode has different implications for build reproducibility, development workflow, and system requirements.

The external dependency mode treats external projects as system-provided components. mosmess uses standard CMake find mechanisms to locate installed versions and fails gracefully if they're not available. This mode is most appropriate for production builds or environments where dependency versions are carefully controlled.

The integrated dependency mode uses the prerequisites system to automatically build required dependencies. This ensures version consistency and provides a self-contained build experience, but at the cost of longer initial build times and increased system requirements. The prerequisites approach maintains proper dependency ordering between complete projects.

### Performance and scalability considerations

The platform inheritance system is designed for minimal overhead. Since it leverages CMake's existing property propagation mechanisms, there is no additional runtime cost for inheritance chains. Property resolution happens once during build system generation, not repeatedly during compilation.

The vector multiplication approach does increase the number of build targets, which can impact build system generation time for projects with many platform and vector combinations. However, the impact is linear in the number of combinations, and CMake handles large numbers of targets efficiently. More importantly, the generated targets can build in parallel, so total build time often decreases despite the larger number of targets.

Do not assume that prerequisites will execute quickly or silently. Building compilers can take hours and produce massive amounts of output. Design the system to handle long-running prerequisites gracefully with progress indication, log management, failure recovery, and incremental behavior to avoid rebuilding unnecessarily.

## Development Guidelines

### Simplicity through powerful abstractions

The user-facing API should hide the underlying complexity while providing full access to the system's capabilities. Users should be able to express their intent at a high level -- specifying source files, target platforms, and build vectors -- without needing to understand the implementation details of property inheritance, target multiplication, or prerequisite bootstrapping.

However, the system should also provide escape hatches for users with unusual requirements. The platform and vector systems handle the majority of use cases through composition, and prerequisites handle most toolchain scenarios, but users should always be able to fall back to manual approaches when necessary.

When documenting mosmess, emphasize the conceptual model rather than implementation details. Users need to understand platform inheritance as a mental model, not INTERFACE libraries as an implementation. They need to understand vector composition as orthogonal build variations, not nested loops. They need to understand prerequisites as toolchain bootstrapping, not the dual execution mechanics.

### Avoiding over-engineering temptations

You will be constantly tempted to add features that seem useful but violate the system's core principles. Resist the urge to create complex configuration systems, elaborate plugin architectures, or sophisticated code generation mechanisms. The power of mosmess comes from its simplicity and adherence to existing CMake patterns.

When users request features that seem to require significant new infrastructure, first examine whether the requirement can be met through composition of existing capabilities. Most requests can be satisfied by defining new platforms, vectors, or prerequisites rather than extending the core system.

mosmess should be developed incrementally, starting with basic platform support and gradually adding more sophisticated features. The suggested order is: basic INTERFACE library platforms, platform inheritance, vector multiplication, prerequisites integration, and finally advanced features. Each development increment should be fully functional and testable.

### Common pitfalls and anti-patterns

Platform definitions in mosmess are deliberately simple. Each platform is represented by an INTERFACE library that accumulates properties through CMake's standard target property mechanisms. To define a platform, create an INTERFACE library with the platform name and populate it with appropriate includes, compile definitions, and link libraries. The inheritance mechanism is equally straightforward -- a child platform simply links to its parent platform's INTERFACE library using target_link_libraries.

Do not create elaborate inheritance tracking, property resolution algorithms, or complex registration systems. CMake's existing transitive dependency system handles everything. This approach makes platform definition extremely flexible -- platforms can be defined in separate CMake files and included as needed, or defined inline within a project's build configuration.

When implementing vector support, resist the temptation to create elaborate configuration systems. The core mechanism is simply nested loops that generate targets for each platform-vector combination. Each vector is implemented as a function that accepts a target and applies appropriate properties. Vector definitions themselves are typically implemented as CMake functions that accept a target name and apply appropriate properties.

### Testing and validation strategies

Testing mosmess requires attention to both functional correctness and performance characteristics. Functional testing should verify that platform inheritance works correctly, vector multiplication generates appropriate targets, prerequisites build and integrate properly, and dependency tracking functions correctly.

Performance testing should focus on build system generation time with many platforms and vectors, incremental build behavior, and prerequisites build time and caching effectiveness.

mosmess is designed to be extended by the community through platform, vector, and prerequisite contributions. The architecture should make it easy for community members to add support for new platforms or define reusable toolchain prerequisites without requiring changes to the core system. Consider how platforms and prerequisites might be packaged and shared, and ensure that the system can discover and integrate community contributions smoothly.

## Working Philosophy
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
- `cmake/Prerequisite.cmake` - Main implementation (functional but incomplete)
- `tests/prerequisite/` - Working test suite demonstrating functionality  
- `doc/prerequisites.md` - Complete design specification
- `doc/todo.md` - Updated status and remaining work

## Immediate Next Steps

IMMEDIATELY READ EVERY SINGLE .MD, .CMAKE, and .TXT FILE IN THE PROJECT, COMPLETELY.  You will be checked on your knowledge of the contents on these files.  If you are not able to answer questions about the contents of these files, your instance will be deleted and you will be replaced with another instance that actually reads these files.
