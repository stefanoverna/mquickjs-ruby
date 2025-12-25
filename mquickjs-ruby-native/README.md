# MQuickJS Ruby Native Extension

High-performance JavaScript sandbox for Ruby using native C extension.

## Features

- ✅ **Native C extension** - Better performance than FFI version
- ✅ **Memory-safe execution** - Fixed memory buffers, isolated from system
- ✅ **CPU limiting** - Configurable timeout enforcement
- ✅ **Console.log capture** - Automatic console output capture
- ✅ **Complete test coverage** - All 27 tests passing (51 assertions)
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
ruby -I lib test/mquickjs_test.rb
# 27 runs, 51 assertions, 0 failures
```

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
