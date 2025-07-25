# CMake Prerequisites

A CMake module that solves the bootstrap problem: building tools that CMake itself needs to find.

[![CI](https://github.com/jbyrd/prerequisites/workflows/CI/badge.svg)](https://github.com/jbyrd/prerequisites/actions)
[![Documentation](https://img.shields.io/badge/docs-comprehensive-blue)](#documentation)

## The Problem

You want to build a project that needs a specific compiler, but that compiler doesn't exist on your system yet. You need to build it from source first. Here's the catch: CMake's `project()` command tries to find your compiler before you've had a chance to build it.

This creates an impossible situation. CMake needs the compiler to configure your project, but you need CMake to build the compiler. Neither can proceed without the other.

This happens more often than you might think. Cross-compilers for embedded systems. Custom code generators. Specialized build tools. Domain-specific language compilers. Static analyzers. Any tool that CMake needs to find but doesn't exist as a pre-built binary for your platform.

## The Solution

Prerequisites breaks this deadlock by building your tools before CMake looks for them. It runs during the initial configuration step, builds whatever you need from source, then lets CMake continue normally.

```cmake
cmake_minimum_required(VERSION 3.12)

# Include Prerequisites before project()
include(cmake/Prerequisite.cmake)

# Build LLVM from source before CMake looks for a compiler
Prerequisite_Add(
    llvm
    GIT_REPOSITORY https://github.com/llvm/llvm-project.git
    GIT_TAG        llvmorg-17.0.0
    CONFIGURE_COMMAND cmake -S llvm -B build -DCMAKE_BUILD_TYPE=Release
    BUILD_COMMAND     cmake --build build --target clang
    INSTALL_COMMAND   cmake --install build --prefix @PREREQUISITE_INSTALL_DIR@
)

# Now CMake can find the compiler we just built
project(MyProject LANGUAGES C CXX)
```

When you run `cmake`, it pauses configuration, builds LLVM from source, installs it, then continues. By the time `project()` runs, your custom compiler is ready and waiting.

## Why This Matters for Development

Prerequisites doesn't just solve the initial bootstrap problem. It makes tool development part of your normal workflow.

During initial setup, tools get built automatically when you run `cmake`. No manual steps, no hunting for the right binaries, no version mismatches. Everyone on your team gets exactly the same tools built from the same source.

During daily development, Prerequisites creates normal CMake targets for your tools. When you modify a tool's source code, it rebuilds automatically as part of your regular build. You can iterate on both your tools and the code that uses them in the same development cycle.

For CI/CD, you get completely reproducible builds. Every tool is built from a known source state. No external dependencies to manage or binaries to trust.

## Common Use Cases

**Custom Compilers and Cross-Compilers**
Building domain-specific languages, experimental compiler backends, or cross-compilers for embedded systems that aren't available as pre-built packages.

**Code Generators and Processors**
Protocol buffer compilers, parser generators, template processors, or any tool that generates source code your build depends on.

**Build and Analysis Tools**
Custom formatters, static analyzers, test runners, or documentation generators that need to be built for your specific platform and configuration.

**Libraries with Required Tools**
Many libraries include executables you need during the build process. Prerequisites can build the entire library and make its tools available to CMake.

## How It Works

Prerequisites operates in two modes that work together seamlessly.

**Immediate mode** runs during CMake configuration. When you call `Prerequisite_Add()` before `project()`, Prerequisites checks if the tool needs building. If it does, it builds it right then and there using the same commands you specified. Configuration pauses until the tool is ready.

**Deferred mode** creates normal CMake targets for ongoing development. Prerequisites generates build targets like `llvm-build` and `llvm-install` that you can invoke manually or depend on from other targets. These targets use the same commands as immediate mode, so your tools behave consistently regardless of when they're built.

This dual approach means you write your build instructions once and they work for both bootstrap and development. No separate build scripts to maintain, no duplication of logic.

## Installation

**For Bootstrap Projects (Recommended)**
```bash
curl -O https://raw.githubusercontent.com/jbyrd/prerequisites/main/cmake/Prerequisite.cmake
# Place in your cmake/ directory
```

**For Library Projects**
```cmake
include(FetchContent)
FetchContent_Declare(
    Prerequisites
    GIT_REPOSITORY https://github.com/jbyrd/prerequisites.git
    GIT_TAG        v1.0.0
)
FetchContent_MakeAvailable(Prerequisites)
```

**For Development**
```bash
git submodule add https://github.com/jbyrd/prerequisites.git prerequisites
```

## Examples

**Building GCC from Source**
```cmake
Prerequisite_Add(
    gcc
    URL https://gcc.gnu.org/releases/gcc-13.2.0/gcc-13.2.0.tar.gz
    URL_HASH SHA256=8cb4be3796651976f94b9356fa08d833524f62420d6292c5033a9a26af315078
    CONFIGURE_COMMAND ../src/configure --prefix=@PREREQUISITE_INSTALL_DIR@ --enable-languages=c,c++
    BUILD_COMMAND     make -j4
    INSTALL_COMMAND   make install
)
```

**Git Repository with Smart Rebuilds**
```cmake
Prerequisite_Add(
    my_tool
    GIT_REPOSITORY https://github.com/example/my-tool.git
    BUILD_DEPENDS  GLOB_RECURSE @PREREQUISITE_SOURCE_DIR@/src/*.cpp @PREREQUISITE_SOURCE_DIR@/src/*.h
    CONFIGURE_COMMAND cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
    BUILD_COMMAND     cmake --build build
    INSTALL_COMMAND   cmake --install build --prefix @PREREQUISITE_INSTALL_DIR@
)
```

The `BUILD_DEPENDS` option tells Prerequisites to rebuild when source files change. Now when you modify the tool's code, it rebuilds automatically as part of your normal development workflow.

**Complex Dependency Chains**
```cmake
# Build LLVM first
Prerequisite_Add(
    llvm
    GIT_REPOSITORY https://github.com/llvm/llvm-project.git
    CONFIGURE_COMMAND cmake -S llvm -B build
    BUILD_COMMAND     cmake --build build --target clang
    INSTALL_COMMAND   cmake --install build --prefix @PREREQUISITE_INSTALL_DIR@
)

# Then build a library that needs LLVM
Prerequisite_Add(
    my_library
    DEPENDS llvm  # Ensures build order
    GIT_REPOSITORY https://github.com/example/my-library.git
    CONFIGURE_COMMAND cmake -S . -B build -DCMAKE_PREFIX_PATH=@llvm_INSTALL_DIR@
    BUILD_COMMAND     cmake --build build
    INSTALL_COMMAND   cmake --install build --prefix @PREREQUISITE_INSTALL_DIR@
)
```

## What Makes This Different

ExternalProject runs at build time, after CMake has already tried to find your tools. By then it's too late for bootstrapping.

FetchContent works great for CMake-based libraries, but it assumes your toolchain already exists. It can't help when you need to build the tools that CMake itself depends on.

Custom shell scripts break incremental builds, don't integrate with CMake's dependency tracking, and aren't portable across platforms.

Prerequisites is the only CMake tool that runs before `project()` and can build the tools that CMake needs to find. It's specifically designed to solve the bootstrap problem while maintaining all the benefits of normal CMake development.

## Features

**Complete Step Lifecycle**
Prerequisites supports the full software build process: download, update, configure, build, install, and test. Skip the steps you don't need, or use them all for complex builds.

**Smart Dependency Tracking**
Choose between simple stamp files for fast builds or detailed file dependency tracking for intelligent rebuilds. Mix both approaches as needed.

**Variable Substitution**
All commands support `@PREREQUISITE_*@` variable expansion for paths and configuration. Write portable build scripts that work in any environment.

**Force Targets**
Every step gets a corresponding force target for debugging and recovery. `make llvm-force-build` will rebuild even if Prerequisites thinks it's up to date.

**Cross-Platform**
Uses CMake's built-in commands for maximum portability. Works anywhere CMake works, without external tool dependencies.

## Testing

Prerequisites includes a comprehensive test suite covering all major functionality:

```bash
cd tests && cmake . && ctest
# 26/26 tests passing
```

The tests verify immediate and deferred execution, file dependency tracking, variable substitution, stamp file behavior, and error handling. See [docs/testing.md](docs/testing.md) for detailed coverage analysis.

## Requirements

- CMake 3.12 or later
- Git (for GIT_REPOSITORY downloads)
- Network access (for URL downloads during configuration)

## Documentation

- [Complete API Reference](docs/prerequisites.md) - All functions and options
- [Testing Guide](docs/testing.md) - Test suite overview and coverage
- [Development Guide](docs/DEVELOPMENT.md) - Contributing and architecture

## Projects Using Prerequisites

- [mosmess](https://github.com/jbyrd/mosmess) - MOS 6502 cross-platform embedded SDK

## License

MIT License - see [LICENSE](LICENSE) file.

## Contributing

Bug reports, feature requests, and pull requests welcome. Please include tests for new functionality and run the full test suite before submitting.

---

**Prerequisites: Build the tools that build the tools.**