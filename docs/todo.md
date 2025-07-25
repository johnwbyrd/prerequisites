# Todo

## Current Status

**Prerequisites System: CORE FUNCTIONALITY COMPLETE**
- Dual execution model fully implemented and tested (26/26 tests passing)
- Configure-time detection working in nested CMake contexts (CTest)
- File dependency tracking with GLOB patterns implemented
- Variable substitution system working for all supported variables
- Stamp-based dependency tracking with proper chaining
- Build target generation and force targets
- Property storage and retrieval system complete
- Comprehensive test suite covering core functionality

**Test Coverage Analysis:**
- **Well-tested (25%)**: Core execution model, BUILD_COMMAND, basic file dependencies, stamp behavior
- **Untested (75%)**: Git/URL downloads, logging system, custom directories, multi-step workflows, force targets

## High Priority Implementation Gaps

### 1. Download Source Support (CRITICAL MISSING FUNCTIONALITY)

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

### 2. Multi-Step Workflow Support (MAJOR GAP)

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

### 3. Logging System (DOCUMENTED BUT NOT IMPLEMENTED)

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

### 4. Directory Customization (PARSING ONLY, NO TESTING)

**Untested directory options:**
- `PREFIX`, `SOURCE_DIR`, `BINARY_DIR`, `INSTALL_DIR`, `STAMP_DIR`, `LOG_DIR`
- Custom directory inheritance and defaults
- Directory creation and validation

**Current limitation:**
- Default directory structure works fine
- Custom directory specification untested
- No validation of directory option interactions

### 5. Advanced Features (IMPLEMENTED BUT UNTESTED)

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

## Medium Priority Extensions

### 1. Prerequisite Dependencies (BASIC IMPLEMENTATION EXISTS)
- `DEPENDS <prereqs...>` option parsed but testing is limited
- Multi-prerequisite dependency chains need validation
- Build-time vs configure-time dependency behavior testing

### 2. Control Options  
- `<STEP>_ALWAYS` flags - Parsed but no implementation or testing
- `BUILD_IN_SOURCE` - No implementation
- Advanced step control mechanisms

### 3. Platform Integration Preparation
- Prerequisites → platforms integration design
- External tool discovery (find existing installations vs building)
- Toolchain integration patterns