# MQuickJS Test Suite

This directory contains comprehensive test coverage for the MQuickJS Ruby sandbox.

## Test Files

### fetch_test.rb

Comprehensive test coverage for the `fetch()` API interface. This test suite covers:

- **Basic Request Tests** (7 tests): GET, POST, PUT, DELETE, PATCH, HEAD, OPTIONS
- **Request Body Tests** (5 tests): String bodies, JSON, empty body, missing body, special characters
- **Response Property Tests** (12 tests): status, statusText, ok, body, headers, all properties
- **HTTP Status Code Tests** (12 tests): 200, 201, 204, 301, 302, 400, 401, 403, 404, 500, 502, 503
- **JSON Parsing Tests** (4 tests): Simple objects, arrays, nested objects, special characters
- **URL Tests** (6 tests): HTTPS, HTTP, query params, ports, path segments, hash fragments
- **Error Handling Tests** (8 tests): Missing URL, no callback, invalid types, null/undefined options
- **Options Object Tests** (8 tests): Method variations, null/undefined values, extra properties
- **Multiple Request Tests** (3 tests): Sequential requests, function calls, loops
- **Edge Cases** (8 tests): Reusability, type checking, variable storage, object/array storage
- **Unicode Tests** (2 tests): Unicode in response body, very long URLs
- **Console Integration Tests** (2 tests): Logging with fetch, logging response properties
- **Ruby Callback Tests** (6 tests): Parameter passing, custom responses, method-based logic
- **Case Sensitivity Tests** (2 tests): Method and URL case preservation

**Total: 83 comprehensive tests**

## Current Status

⚠️ **IMPORTANT**: The native `fetch()` implementation is currently experiencing segmentation faults due to issues with the binary-encoded stdlib modifications. The test suite documents the expected behavior and API surface area for when the implementation is fixed.

### Known Issues

1. **Stdlib Segfault**: Modifications to `mqjs_stdlib.h` to add the `fetch` atom cause segfaults during sandbox initialization at `stdlib_init` (mquickjs.c:3502)
2. **Binary Format Sensitivity**: The mquickjs stdlib uses a binary-encoded format that is extremely fragile to modifications
3. **Offset Calculations**: Both commits 82a3403 and 1d7d03a attempted to fix offset calculations but still have segfaults

### Alternative Approaches

See `IMPLEMENTATION_ROADMAP.md` and `NEXT_STEPS.md` for alternative implementation strategies, including:
- **Phase 1**: HTTPPreprocessor (JavaScript code transformation)
- **Phase 2**: Eval-based injection
- **Phase 3**: Upstream stdlib generation tools

## Running Tests

Once the `fetch()` implementation is working:

```bash
cd mquickjs-ruby-native
ruby test/fetch_test.rb
```

## Prerequisites

The native extension must be compiled with the mquickjs source available:

```bash
# Clone mquickjs source to /tmp/
git clone https://github.com/bellard/mquickjs.git /tmp/mquickjs

# Compile the extension
cd ext/mquickjs
make clean
ruby extconf.rb
make

# Copy to lib directory
cp mquickjs_native.so ../../lib/mquickjs/
```

## Test Coverage Goals

The test suite is designed to:
1. **Document the API**: Serve as executable documentation of the fetch() interface
2. **Prevent Regressions**: Catch breaking changes when implementation is fixed
3. **Guide Implementation**: Provide clear requirements for what needs to be implemented
4. **Validate Behavior**: Ensure Ruby callback integration works correctly

## Contributing

When fixing the `fetch()` implementation:
1. Ensure all 83 tests pass
2. The tests cover the full API surface area as designed
3. Add additional tests if new edge cases are discovered
