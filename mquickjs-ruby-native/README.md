# MQuickJS Ruby Native Extension

High-performance JavaScript sandbox for Ruby using native C extension.

## Features

- ✅ **Native C extension** - Better performance than FFI version
- ✅ **Memory-safe execution** - Fixed memory buffers, isolated from system
- ✅ **CPU limiting** - Configurable timeout enforcement
- ✅ **Console.log capture** - Automatic console output capture
- ✅ **Complete test coverage** - 46 tests passing (116 assertions)
- ✅ **HTTP infrastructure** - Complete Ruby layer with security
- ✅ **Production-ready** - Proper Ruby C API integration

## Building

```bash
# Generate Makefile
cd ext/mquickjs
ruby extconf.rb

# Compile extension  
make

# Copy to lib directory
cp mquickjs_native.so ../../lib/mquickjs/
```

## Testing

```bash
# Run all tests
ruby -I lib test/run_all_tests.rb
# 46 runs, 116 assertions, 0 failures

# Individual test suites:
ruby -I lib test/mquickjs_test.rb       # 27 sandbox tests (51 assertions)
ruby -I lib test/http_config_test.rb    # 13 HTTP config tests (46 assertions)
ruby -I lib test/http_executor_test.rb  # 6 HTTP executor tests (19 assertions)
```

**Test Coverage:**
- ✅ JavaScript sandbox (memory limits, timeouts, console.log)
- ✅ HTTP configuration (whitelist, IP blocking, security)
- ✅ HTTP executor (validation, rate limiting, error handling)

## Usage

```ruby
require 'mquickjs'

# Simple evaluation
result = MQuickJS.eval("1 + 2 + 3")
result.value  # => 6

# With console capture
result = MQuickJS.eval("console.log('Hello'); 42")
result.value            # => 42
result.console_output   # => "Hello\n"
```

## Performance

The native extension provides significant performance improvements over the FFI version:
- No FFI call overhead
- Direct Ruby C API integration
- Optimized value conversion
- Better memory management

## Implementation Details

- Uses Ruby's TypedData API for memory management
- Proper GC integration via `sandbox_free` and `sandbox_memsize`
- Thread-safe console output capture
- Correct JSValue to Ruby value conversion for 64-bit architecture

See parent directory documentation for complete API reference.
