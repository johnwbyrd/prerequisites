# CMake Prerequisites

A CMake module for building external dependencies during configuration phase, before the `project()` command runs.

[![Tests](https://img.shields.io/badge/tests-26%2F26%20passing-brightgreen)](#testing)
[![Documentation](https://img.shields.io/badge/docs-comprehensive-blue)](#documentation)

## Why Prerequisites?

CMake's `project()` command assumes your toolchain exists. But what if you're building that compiler from source? What if you need custom libraries that don't exist yet? 

**The Bootstrap Problem:** CMake needs these tools to configure your project, but you need CMake to build the tools.

**The Solution:** Prerequisites breaks this deadlock by building dependencies immediately during configuration (so they're ready when `project()` runs), while also creating normal CMake targets for incremental rebuilds.

ExternalProject can't help here -- it only runs at build time. FetchContent is great for CMake-based libraries, but can't bootstrap compilers. Prerequisites handles both bootstrap and development in one system.

## Quick Start

```cmake
cmake_minimum_required(VERSION 3.25)

# Include Prerequisites before project()
include(cmake/Prerequisite.cmake)

# Build a compiler before CMake looks for one
Prerequisite_Add(
    llvm_mos
    GIT_REPOSITORY https://github.com/llvm-mos/llvm-mos.git
    GIT_TAG        main
    CONFIGURE_COMMAND cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
    BUILD_COMMAND     cmake --build build --target clang
    INSTALL_COMMAND   cmake --install build --prefix @PREREQUISITE_INSTALL_DIR@
)

# Now CMake can find the compiler we just built
project(MyProject LANGUAGES C CXX)
```

## Core Features

### Dual Execution Model
- **Configure-time**: Runs immediately before `project()` for bootstrapping
- **Build-time**: Creates normal CMake targets for incremental rebuilds
- Same commands work in both modes automatically

### Flexible Dependency Tracking
- **Stamp files**: Simple, fast (default)
- **File dependencies**: Smart rebuilds using GLOB patterns
- Mix both approaches per step as needed

### Full Step Lifecycle
- **download** → **update** → **configure** → **build** → **install** → **test**
- Skip unused steps, trigger chains automatically
- Force targets for debugging and recovery

### Variable Substitution
All commands support `@PREREQUISITE_*@` variable expansion:
```cmake
BUILD_COMMAND make -j4 install PREFIX=@PREREQUISITE_INSTALL_DIR@
```

## Installation

### Method 1: Copy File (Recommended for Bootstrap)
```bash
# For projects that need immediate bootstrap capability
curl -O https://raw.githubusercontent.com/jbyrd/prerequisites/main/cmake/Prerequisite.cmake
# Place in your cmake/ directory
```

### Method 2: FetchContent (For Libraries)
```cmake
include(FetchContent)
FetchContent_Declare(
    Prerequisites
    GIT_REPOSITORY https://github.com/jbyrd/prerequisites.git
    GIT_TAG        v1.0.0
)
FetchContent_MakeAvailable(Prerequisites)
```

### Method 3: Git Submodule
```bash
git submodule add https://github.com/jbyrd/prerequisites.git prerequisites
```

## Documentation

- **[API Reference](docs/api.md)** - Complete function and option reference
- **[Examples](examples/)** - Real-world usage patterns
- **[Testing Guide](docs/testing.md)** - Test suite overview and coverage
- **[Development](docs/DEVELOPMENT.md)** - Contributing and architecture

## Examples

### Git Repository with File Dependencies
```cmake
Prerequisite_Add(
    zlib
    GIT_REPOSITORY https://github.com/madler/zlib.git  
    GIT_TAG        v1.2.11
    BUILD_DEPENDS  GLOB @PREREQUISITE_SOURCE_DIR@/*.c @PREREQUISITE_SOURCE_DIR@/*.h
    CONFIGURE_COMMAND ./configure --prefix=@PREREQUISITE_INSTALL_DIR@
    BUILD_COMMAND     make -j4
    INSTALL_COMMAND   make install
)
```

### URL Download with Hash Verification
```cmake
Prerequisite_Add(
    openssl
    URL      https://www.openssl.org/source/openssl-1.1.1.tar.gz
    URL_HASH SHA256=2836875a0f89c03d0fdf483941512613a50cfb421d6fd94b9f41d7279d586a3d
    CONFIGURE_COMMAND ./config --prefix=@PREREQUISITE_INSTALL_DIR@
    BUILD_COMMAND     make -j4
    INSTALL_COMMAND   make install
)
```

### Multi-Step Build Chain
```cmake
# Build compiler first
Prerequisite_Add(llvm_mos ...)

# Then build library using that compiler  
Prerequisite_Add(
    picolibc
    DEPENDS llvm_mos  # Ensures proper build order
    GIT_REPOSITORY https://github.com/picolibc/picolibc.git
    # Configure step can now use compiler from llvm_mos
    CONFIGURE_COMMAND meson setup build --cross-file=@PREREQUISITE_INSTALL_DIR@/toolchain.txt
    BUILD_COMMAND     ninja -C build
    INSTALL_COMMAND   ninja -C build install
)
```

## Testing

Prerequisites includes a comprehensive test suite covering:
- Core execution model (immediate vs deferred)
- File dependency tracking with GLOB patterns  
- Variable substitution in all contexts
- Stamp file behavior and incremental builds
- Error handling and recovery

```bash
cd tests && cmake . && ctest
# 26/26 tests passing
```

See [docs/testing.md](docs/testing.md) for detailed test coverage analysis.

## Requirements

- **CMake 3.25+** (uses PARSE_ARGV and other modern features)
- **Git** (for GIT_REPOSITORY downloads)
- **Network access** (for URL downloads during configure)

## License

MIT License - see [LICENSE](LICENSE) file.

## Contributing

1. **Issues**: Bug reports, feature requests, questions welcome
2. **Pull Requests**: Please include tests for new functionality  
3. **Testing**: Run full test suite before submitting
4. **Documentation**: Update docs for API changes

See [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) for architecture details and development setup.

## Projects Using Prerequisites

- **[mosmess](https://github.com/jbyrd/mosmess)** - MOS 6502 cross-platform embedded SDK
- *Add your project here!*

---

**Prerequisites: Because sometimes you need to build the tools that build the tools.**