# MQuickJS Ruby Sandbox

A safe JavaScript sandbox for Ruby using [mquickjs](https://github.com/bellard/mquickjs), a minimal JavaScript engine designed for embedded systems.

## Features

- ✅ **Memory-safe execution** - Fixed memory buffers, no system malloc access
- ✅ **CPU limiting** - Configurable timeout enforcement via interrupt handlers
- ✅ **Isolated execution** - No filesystem or network access by default
- ✅ **Console.log capture** - Captures and returns console output with size limits
- ✅ **HTTP support (infrastructure)** - Whitelist-based HTTP with comprehensive security
- ✅ **Clear error handling** - Distinct exceptions for different failure modes
- ✅ **Comprehensive tests** - 27 sandbox tests + 13 HTTP config tests passing

## Installation

This is currently a development gem. To use it:

```bash
# Build the mquickjs shared library
./build_mquickjs.sh

# Run tests
ruby test_mquickjs.rb
ruby test_http_config.rb
```

## Quick Start

```ruby
require 'mquickjs'

# Simple one-shot evaluation
result = MQuickJS.eval("1 + 2 + 3")
result.value  # => 6

# With custom limits
result = MQuickJS.eval(
  "var sum = 0; for (var i = 0; i < 100; i++) sum += i; sum",
  memory_limit: 10_000,    # 10KB
  timeout_ms: 1000         # 1 second
)
result.value  # => 4950

# Console output capture
result = MQuickJS.eval("console.log('Hello'); console.log('World'); 42")
result.value            # => 42
result.console_output   # => "Hello\nWorld\n"
result.console_truncated?  # => false
```

## Testing

```bash
# Main sandbox tests
ruby test_mquickjs.rb
# 27 runs, 51 assertions, 0 failures

# HTTP configuration tests
ruby test_http_config.rb
# 13 runs, 46 assertions, 0 failures
```

## Roadmap

- [x] FFI-based Ruby bindings
- [x] Memory and CPU limits
- [x] Console.log capture with truncation
- [x] HTTP security infrastructure (Ruby layer)
- [x] Comprehensive test coverage
- [ ] Native C extension for better performance
- [ ] Full HTTP JavaScript integration (in C extension)
- [ ] Additional JS APIs as needed
- [ ] Gem packaging and release

See [API_DESIGN.md](../../API_DESIGN.md) and [HTTP_SECURITY_DESIGN.md](../../HTTP_SECURITY_DESIGN.md) for complete documentation.
