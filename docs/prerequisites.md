# CMake prerequisites system

## Introduction

The prerequisites system lets you build external dependencies during CMake's configuration phase, before the `project()` command runs. This is crucial when you need to build the very tools that CMake is about to look for.

For example: CMake's `project()` command needs a working compiler and maybe some libraries. It runs detection tests, checks features, and generally assumes your toolchain exists. But what if you're building that compiler from source? What if you need a custom library that doesn't exist yet? You're stuck -- CMake needs these tools to configure your project, but you need CMake to build the tools.

The prerequisites system breaks this deadlock. It can build your dependencies immediately during configuration (so they're ready when `project()` runs), and it also creates normal CMake targets for incremental rebuilds later.

ExternalProject can't help here -- it only runs at build time, after configuration is done. FetchContent is great for pulling in CMake-based libraries, but it can't bootstrap a compiler. Prerequisites handles both the bootstrap problem and ongoing development in one system.

## Core concepts

### Dual execution model

The prerequisites system can run at both configure time _and_ at build time. This isn't an accident -- it's what makes the whole thing useful.

When you call `Prerequisite_Add()` before `project()`, the system checks if your prerequisite needs building. If it does, it runs the build steps right then and there using `execute_process()`. Your CMake configuration pauses, the compiler gets built, and then configuration continues. This is how you bootstrap -- by the time CMake hits `project()` and starts looking for a compiler, it's already there.

But the system _also_ creates regular CMake targets for every prerequisite. These targets check the same stamp files and run the same commands, but they execute during the build phase like any other target. So if you modify your prerequisite's source code and rebuild your main project, the prerequisite rebuilds automatically.

This dual approach means you write your prerequisite once and it works for both scenarios. Initial bootstrap? It runs immediately. Daily development? It's just another dependency. Same code, same commands, two execution paths.

### Dependency tracking methods

The prerequisites system needs to know when to rebuild things. It offers two ways to track this: simple stamp files or detailed file dependencies.

By default, the system uses stamp files -- just empty files that mark when a step completed successfully. If the stamp exists, the step is done. If it's missing, the step runs. This is fast and simple, but it's all-or-nothing. The downside is changes to your prerequisite's source files are not automatically detected, and your prerequisite is not automatically rebuilt.  

The alternative is file dependency tracking. You tell each step which files it actually depends on, by using CMake's file glob patterns. Before running a step, the system checks if any of those files are newer than the stamp. Changed a source file? Only the build step reruns. Changed CMakeLists.txt? Now configure needs to run too. It's smarter and saves time, especially with large projects.

The catch is that file tracking requires more setup and more build-time overhead. You need to know which files matter for each step, write the glob patterns correctly, and accept that checking hundreds of file timestamps in your prerequisite, takes some incremental amount of time.

Most projects mix both approaches by choosing the appropriate method for each step. Use stamps for stable steps (download, configure) and use dependency tracking for steps where you need automatic rebuilds (build, install). A typical setup might use file dependency tracking for the build step but use simple stamps for everything else. This gets you fast rebuilds during development without overcomplicating the whole system.

Each step uses either mere stamp tracking or additional file dependency tracking. The choice determines how that step decides when it needs to run.

### Step-based architecture

Prerequisites are built through a series of ordered steps, mimicking how you'd build software manually. Each step has a specific job and they run in a fixed sequence.

The standard steps are: download, update, configure, build, install, and test. Not every prerequisite uses all steps -- you might skip update if you're building from a tarball, or skip test if there's nothing to test. But when steps do run, they always run in this order.

Here's the key rule: when you trigger any step, all subsequent steps run too. Ask for build? You get build, install, and test. Ask for download? You get the whole chain. This seems wasteful at first, but it ensures consistency. If you've changed the build, the old installation is stale. If you've downloaded new source, the old build is useless. The only exception is the test step -- you can run tests repeatedly without triggering anything else.

Each step is just a command or set of commands. Download might run `git clone`. Configure might run `cmake` or `./configure`. Build runs `make` or `ninja`. You provide these commands when defining your prerequisite, and the system runs them at the appropriate time with the appropriate checks.

This design keeps prerequisites predictable. You always know what will happen when you trigger a step, and you can't accidentally end up with a partially updated prerequisite where the headers don't match the libraries.

Remember that each step uses either stamp tracking or file dependency tracking -- one or the other, never both. You might use simple stamps for download and configure, but switch to file dependency tracking just for the build step. This per-step choice lets you optimize exactly where it matters.

## System design

### Execution flow

When you call `Prerequisite_Add()`, several things happen in sequence, and the order matters.

First, the function stores all your settings -- the commands, directories, dependencies, everything. This information needs to be available later, whether for immediate execution or for creating build targets.

Next, if you're running before `project()`, the system checks whether this prerequisite needs to build. For each step, it checks dependencies - either looking for stamp files or checking if tracked files have changed, depending on how you configured that step. If any step needs to run, it executes immediately using `execute_process()`. The system runs the command, checks if it succeeded, and updates tracking information (stamps or file lists). This all happens during CMake configuration, blocking until done.

Then, regardless of whether anything built, the system creates CMake targets for every step. It generates `add_custom_command()` rules that respect the same dependency logic - stamps for some steps, file dependencies for others. Some steps might not produce stamps at all if they're using file tracking exclusively. The dependency chain ensures steps run in order, using whatever tracking method each step requires. The system also creates convenient targets like `myprereq-build` that you can invoke directly or use with `add_dependencies()`, which in turn use ordinary CMake dependencies for running that step as well as previous ones, as needed.

Whether a step runs immediately during configuration or later during build, it uses the same commands and the same dependency logic. The only difference is timing -- immediate when bootstrapping, deferred when developing.

### Directory layout

Prerequisites need a place to download source, build, and install files. The system uses a predictable layout that keeps things organized and avoids conflicts.

By default, everything goes under a PREFIX directory, following ExternalProject's layout exactly. If you don't specify a PREFIX, it defaults to `<name>-prefix`. For a prerequisite named `myprereq`, you'd get:
- `PREFIX/src/myprereq` - Source code lives here
- `PREFIX/src/myprereq-build` - Build happens here (out-of-source)
- `PREFIX/src/myprereq-stamp` - Stamp files track completion
- `PREFIX/src` - Downloaded files go here before extraction
- `PREFIX/tmp` - Temporary files during operations
- `PREFIX` - Installation goes directly in prefix

This matches ExternalProject's directory structure exactly, so it'll feel familiar if you've used that. The separation between source and build directories enables clean out-of-source builds, which most modern projects expect.

You can override any of these locations. Maybe you have source code already checked out somewhere, or you want stamps in a specific spot for caching. Just set SOURCE_DIR, BINARY_DIR, STAMP_DIR, DOWNLOAD_DIR, or INSTALL_DIR when calling `Prerequisite_Add()`. The system respects your choices and adjusts all the internal paths accordingly.

The PREFIX approach also makes it easy to share installations. Multiple prerequisites can install into the same PREFIX, creating a unified location for all your bootstrapped tools. This is especially handy when building a complete toolchain where later prerequisites need to find earlier ones.

### Stamp files vs dependency tracking

When a step finishes successfully, the system creates an empty file in the stamp directory. For a prerequisite named `myprereq`, you'd see files like `myprereq-download`, `myprereq-configure`, `myprereq-build`, etc. These aren't complex databases or logs -- just empty marker files whose timestamps indicate the completion of a step.  A target 

When a step fails, the system cleans up by removing stamps for that step and all subsequent steps. This prevents inconsistent states where you might have a build stamp but no install stamp because the build actually failed. It's better to rebuild too much than to have a half-working prerequisite.

File dependency tracking replaces stamp files entirely for that step. When you add file dependencies to a step, that step no longer creates or uses stamp files. Instead, the system uses CMake's normal file dependency logic -- the step runs when any tracked files are newer than the step's actual outputs, or when outputs are missing. This gives you precise rebuilds based on what actually changed.

Steps using stamp tracking can be manually controlled by deleting stamp files to force rebuilds. Want to reconfigure a stamp-tracked step? Delete `myprereq-configure` and all later stamps. Steps using file dependencies are controlled by CMake's normal dependency system -- they run automatically when their inputs change.

### Build target generation

The prerequisites system creates standard CMake targets for every prerequisite, giving you normal CMake integration alongside the bootstrap capability.

For each step in your prerequisite, the system generates a `myprereq-step` target.  A prerequisite named `myprereq` gets targets like `myprereq-download`, `myprereq-build`, `myprereq-install`, etc. These targets depend on whatever output their step produces -- stamp files for stamp-tracked steps, or the actual command execution for file-tracked steps.

Additionally, the system creates "force" targets that bypass dependency checking entirely. These targets have names like `myprereq-force-download`, `myprereq-force-configure`, `myprereq-force-build`, etc. When invoked, a force target deletes the stamp file for that step and all subsequent steps, then runs those steps regardless of timestamps. This is useful for debugging, testing changes, or recovering from build issues.

Example: `make myprereq-force-build` will delete build/install/test stamps and re-run build, install, and test steps even if they appeared up-to-date.

The beauty of this approach is that these are just normal CMake targets. You can use them with `add_dependencies()` to make your main project depend on prerequisite steps. You can invoke them manually from the command line. They participate in parallel builds and respect CMake's dependency tracking.

Most importantly, these targets run the exact same commands as immediate execution. Whether a step runs during configuration or during build via these targets, the commands, arguments, and environment are identical. This consistency means prerequisites behave the same way regardless of when they execute.

## Usage patterns

### Basic bootstrapping

The most common use of prerequisites is building a compiler before CMake's project() command needs to detect it. This solves the fundamental problem where CMake requires a working toolchain to configure your project, but you need to build that toolchain from source.

```cmake
Prerequisite_Add(llvm-mos
  GIT_REPOSITORY https://github.com/llvm-mos/llvm-mos.git
  CONFIGURE_COMMAND ${CMAKE_COMMAND} @PREREQUISITE_SOURCE_DIR@ -DCMAKE_BUILD_TYPE=Release
  BUILD_COMMAND ${CMAKE_COMMAND} --build @PREREQUISITE_BINARY_DIR@
  INSTALL_COMMAND ${CMAKE_COMMAND} --install @PREREQUISITE_BINARY_DIR@
)

project(MyProject C)  # Can now find mos-clang
```

Note that `${CMAKE_COMMAND}` expands immediately when Prerequisite_Add() is called, while `@PREREQUISITE_*@` variables may be substituted immediately or later, depending on when commands actually run. This may be at configure time or build time as appropriate.

When CMake processes the Prerequisite_Add() call, it immediately downloads and builds llvm-mos, pausing configuration until the compiler is ready. The subsequent project() command then successfully detects the newly built compiler and configures your project normally.

### Iterative development

Once prerequisites have built during initial configuration, they integrate seamlessly with your normal development workflow. The prerequisite system creates standard CMake targets for each prerequisite, allowing your main project to depend on them like any other build dependency.

During daily development, you can make your project targets depend on prerequisite steps using add_dependencies(). For example, `add_dependencies(my_app llvm-mos-install)` ensures the compiler is built and installed before your application builds. If prerequisite source code hasn't changed, the stamp files or the file dependencies prevent unnecessary rebuilds. However, if necessary, you can edit source files in a prerequisite, and either force a rebuild via the llvm-mos-force-build target, or you can use file glob tracking to cause the rebuild to happen automatically.

### Mixed dependency tracking

Choose stamp files for stable steps where you don't expect to modify source files, and choose file dependency tracking for steps where you're actively editing and iterating. Each step uses one method or the other.

For example, the download and configure steps rarely need to re-run during development -- you're not typically modifying the upstream repository or changing build configuration. These steps work well with stamp-based tracking. The build step, however, benefits greatly from file dependency tracking if you're applying patches or modifying source files, since it can automatically detect when a rebuild is necessary.

```cmake
Prerequisite_Add(my-lib
  GIT_REPOSITORY https://github.com/example/lib.git
  # Download uses stamp tracking (default)
  CONFIGURE_COMMAND ${CMAKE_COMMAND} -S @PREREQUISITE_SOURCE_DIR@ -B @PREREQUISITE_BINARY_DIR@
  # Build uses file dependency tracking for automatic rebuilds
  BUILD_DEPENDS GLOB_RECURSE @PREREQUISITE_SOURCE_DIR@/*.c @PREREQUISITE_SOURCE_DIR@/*.h
  BUILD_COMMAND make -C @PREREQUISITE_BINARY_DIR@
)
```

This mixed approach gives you automatic rebuilds where you need them without the overhead of tracking files for every step. The performance cost of checking timestamps is only incurred for steps where the automation provides real value.

## Function reference

### Prerequisite_Add

Main function to define a prerequisite.

**Synopsis:**
```- `DEPENDS <prereqs...>` - Names of other prerequisites that must be built first.
  - **Configure time**: Does NOT enforce dependencies -- prerequisites execute in the order they appear in your CMakeLists.txt
  - **Build time**: Creates proper target dependencies so this prerequisite's targets depend on the dependency's targets
  - Example: If A depends on B, then A-install will depend on B-install
  - **Important**: To ensure dependencies are built at configure time, list them in dependency order in your CMakeLists.txt
Prerequisite_Add(<name> [options...])
```

**Note:** For all step command options (*_COMMAND), if no command is specified, that step performs no action. Prerequisites are diverse external projects that require explicit commands for each step. Command and argument options support `@VARIABLE@` substitution using the variables listed in the Command Variable Substitution section.

**Options:**

#### Dependency Options
- `DEPENDS <prereqs...>` - Names of other prerequisites that must be built first. 

  The DEPENDS option behaves differently during configure time versus build time, which is important to understand.

  During configure time, DEPENDS does nothing. Prerequisites execute in the exact order they appear in your CMakeLists.txt file, regardless of any DEPENDS declarations. If you need prerequisite A to build before prerequisite B during configuration, you must physically place the Prerequisite_Add(A) call before the Prerequisite_Add(B) call in your CMakeLists.txt.

  During build time, DEPENDS creates proper CMake target dependencies. If prerequisite A depends on prerequisite B, then all of A's step targets (A-build, A-install, etc.) will depend on the corresponding B targets. This ensures that when you run `make A-install`, it will automatically build B-install first if needed.

#### Directory Options
- `PREFIX <dir>` - Root directory for this prerequisite
- `SOURCE_DIR <dir>` - Source directory (can be pre-existing)
- `BINARY_DIR <dir>` - Build directory
- `INSTALL_DIR <dir>` - Installation directory
- `STAMP_DIR <dir>` - Directory for stamp files
- `LOG_DIR <dir>` - Directory for log files (defaults to STAMP_DIR if not specified)

#### Download Step Options

**Git-based downloads:**
- `GIT_REPOSITORY <url>` - Git repository URL
- `GIT_TAG <tag>` - Git branch, tag, or commit
- `GIT_SHALLOW` - Perform shallow clone

**URL-based downloads:**
- `URL <url>` - Download URL for archives
- `URL_HASH <algo>=<hash>` - Hash verification

**Custom downloads:**
- `DOWNLOAD_COMMAND <cmd...>` - Custom download command
- `DOWNLOAD_NO_EXTRACT` - Don't extract downloaded archives

**Note:** Git-based and URL-based options are mutually exclusive.

#### Update Step Options
- `UPDATE_COMMAND <cmd...>` - Custom update command
- `UPDATE_DISCONNECTED` - Skip update step

#### Configure Step Options
- `CONFIGURE_COMMAND <cmd...>` - Configure command

#### Build Step Options
- `BUILD_COMMAND <cmd...>` - Build command
- `BUILD_IN_SOURCE` - Build in source directory

#### Install Step Options
- `INSTALL_COMMAND <cmd...>` - Install command

#### Test Step Options
- `TEST_COMMAND <cmd...>` - Test command

#### Command Variable Substitution

All command arguments support `@VARIABLE@` substitution:
- `@PREREQUISITE_NAME@` - The prerequisite name
- `@PREREQUISITE_PREFIX@` - The prefix directory  
- `@PREREQUISITE_SOURCE_DIR@` - Source directory path
- `@PREREQUISITE_BINARY_DIR@` - Build directory path
- `@PREREQUISITE_INSTALL_DIR@` - Install directory path
- `@PREREQUISITE_STAMP_DIR@` - Stamp directory path
- `@PREREQUISITE_LOG_DIR@` - Log directory path

Examples:
```cmake
CMAKE_ARGS -DCMAKE_INSTALL_PREFIX=@PREREQUISITE_INSTALL_DIR@
BUILD_COMMAND cmake --build @PREREQUISITE_BINARY_DIR@ --parallel
INSTALL_COMMAND make -C @PREREQUISITE_BINARY_DIR@ install
```

#### Logging Options
- `LOG_DOWNLOAD <bool>` - When true, redirect download step output to log files instead of console
- `LOG_UPDATE <bool>` - When true, redirect update step output to log files instead of console  
- `LOG_CONFIGURE <bool>` - When true, redirect configure step output to log files instead of console
- `LOG_BUILD <bool>` - When true, redirect build step output to log files instead of console
- `LOG_INSTALL <bool>` - When true, redirect install step output to log files instead of console
- `LOG_TEST <bool>` - When true, redirect test step output to log files instead of console
- `LOG_OUTPUT_ON_FAILURE <bool>` - When true, only show captured log output if the step fails

**Normal behavior**: Step output appears directly in CMake configure log or build output
**With LOG_* true**: Step output is captured to automatically named files like `<name>-build-out.log` in LOG_DIR (or STAMP_DIR if LOG_DIR not specified), console shows only summary messages

Example: Without `LOG_BUILD`, you see thousands of compiler lines. With `LOG_BUILD true`, you see "Building prerequisite... (logged to file)" and can examine the log file if needed.

#### File Dependency Options

These options enable intelligent rebuild behavior by tracking changes to specific files within a prerequisite's source tree, rather than relying solely on timestamp-based stamp files.

- `DOWNLOAD_DEPENDS <args...>` - File dependency arguments for download step
- `UPDATE_DEPENDS <args...>` - File dependency arguments for update step
- `CONFIGURE_DEPENDS <args...>` - File dependency arguments for configure step
- `BUILD_DEPENDS <args...>` - File dependency arguments for build step
- `INSTALL_DEPENDS <args...>` - File dependency arguments for install step
- `TEST_DEPENDS <args...>` - File dependency arguments for test step

**Purpose:**
File dependency tracking allows prerequisites to rebuild only when their internal dependencies have actually changed. For example, if you modify source files in a prerequisite, only the build/install/test steps need to re-run, not the download/configure steps. This provides more granular and efficient rebuild behavior than simple timestamp checking.

**File Dependency Behavior:**

When you specify file dependencies for a step, you provide glob patterns that tell the system which files to track. The first argument should typically be `GLOB` or `GLOB_RECURSE`, followed by the actual glob patterns with variable substitution applied. File dependencies completely replace stamp-based tracking for that step -- the step will run when any dependency file is newer than the step's outputs, or when outputs are missing, using CMake's normal dependency resolution.

Examples:
```cmake
Prerequisite_Add(my_project
  GIT_REPOSITORY https://github.com/example/project.git
  GIT_TAG main
  
  # Configure step depends on CMake files
  CONFIGURE_DEPENDS GLOB CMakeLists.txt cmake/*.cmake
  
  # Build step depends on source files recursively  
  BUILD_DEPENDS GLOB_RECURSE
    @PREREQUISITE_SOURCE_DIR@/*.cpp 
    @PREREQUISITE_SOURCE_DIR@/*.h
    
  # Install step depends on build outputs
  INSTALL_DEPENDS GLOB @PREREQUISITE_BINARY_DIR@/bin/*
)
```

#### Control Options
- `BUILD_ALWAYS` - Always rebuild regardless of stamps
- `<STEP>_ALWAYS` - Always run specific step (e.g., `CONFIGURE_ALWAYS`)

### Prerequisite_Get_Property

Retrieve properties from a prerequisite.

**Synopsis:**
```
Prerequisite_Get_Property(<name> <property> <output_variable>)
```

**Properties:**
All options from `Prerequisite_Add` can be retrieved as properties.

**Internal Storage:**
The prerequisites system stores all parsed arguments as CMake global properties using the naming pattern `_PREREQUISITE_${name}_${property_name}`. This approach, similar to ExternalProject and FetchContent, allows prerequisite data to persist across function calls and be accessible to any part of the build system without relying on variable scope limitations.

When `Prerequisite_Add()` processes arguments, it immediately stores them as global properties. Later, `Prerequisite_Get_Property()` retrieves these stored values using `get_property(GLOBAL)`. This design enables the prerequisites system's internal helper functions to access parsed data without complex variable passing schemes, and provides a clean public API for users who need to query prerequisite configuration.

### Force Targets

Force targets are automatically created for each step to enable rebuilding when needed.

**Target Names:**
```
<name>-force-<step>  # e.g., myprereq-force-build
```

**Usage:**
```bash
cmake --build . --target myprereq-force-build
```

Force targets remove the step's stamp file and rebuild the step and all subsequent steps. This is useful for troubleshooting or when you want to force a rebuild regardless of dependency timestamps.