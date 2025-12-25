# MQuickJS Ruby Sandbox (FFI Version)

A safe, sandboxed JavaScript execution environment for Ruby using [mquickjs](https://github.com/bellard/mquickjs) via FFI.

## Features

- **Memory-limited execution**: Set strict memory limits (minimum ~10KB for stdlib)
- **CPU timeout enforcement**: Prevent infinite loops with configurable timeouts
- **Sandboxed by design**: No file system, network, or system access
- **Stricter JavaScript mode**: Disables dangerous features (eval, with, etc.)
- **Clean Ruby API**: Simple, intuitive interface
- **Zero dependencies**: Builds mquickjs from source

## Installation

### Prerequisites

- Ruby 3.0+
- GCC compiler
- FFI gem: `gem install ffi`

### Build

```bash
./build_mquickjs.sh
```

This script:
1. Builds mquickjs from `/tmp/mquickjs` (cloned separately)
2. Compiles it as a shared library with security stubs
3. Copies the library to `lib/mquickjs/ffi/`

## Usage

### Quick Start

```ruby
require 'mquickjs'

# Simple evaluation
result = MQuickJS.eval("1 + 2 + 3")
# => 6

result = MQuickJS.eval("'hello'.toUpperCase()")
# => "HELLO"
```

### Custom Limits

```ruby
# Set memory and timeout limits
result = MQuickJS.eval(
  "var sum = 0; for (var i = 0; i < 100; i++) sum += i; sum",
  memory_limit: 50_000,  # 50KB
  timeout_ms: 1000       # 1 second
)
# => 4950
```

### Reusable Sandbox

```ruby
# Create a sandbox instance
sandbox = MQuickJS::Sandbox.new(
  memory_limit: 100_000,  # 100KB
  timeout_ms: 5000        # 5 seconds
)

# Each eval is isolated - no shared state
sandbox.eval("2 + 2")           # => 4
sandbox.eval("Math.sqrt(16)")   # => 4.0
sandbox.eval("typeof x")        # => "undefined"
```

### Error Handling

```ruby
# Syntax errors
begin
  MQuickJS.eval("var x = ")
rescue MQuickJS::SyntaxError => e
  puts e.message
  # => "SyntaxError: unexpected character in expression"
end

# JavaScript errors
begin
  MQuickJS.eval("throw new Error('oops')")
rescue MQuickJS::JavaScriptError => e
  puts e.message
  # => "Error: oops"
end

# Timeout
begin
  MQuickJS.eval("while(true) {}", timeout_ms: 100)
rescue MQuickJS::TimeoutError => e
  puts e.message
  # => "Execution exceeded 100ms timeout"
end
```

## Architecture

### Security Features

1. **Memory Isolation**: Uses a fixed memory buffer (malloc'd by wrapper)
2. **CPU Limiting**: Interrupt handler checks elapsed time periodically
3. **No I/O**: Stub implementations disable:
   - `console.log()` / `print()` (returns undefined)
   - `load()` (throws error)
   - `setTimeout()` / `clearTimeout()` (throws error)
4. **Stricter Mode**: mquickjs automatically disables:
   - Direct `eval()`
   - `with` statements
   - Array holes
   - Value boxing

### Components

```
mquickjs-ruby-ffi/
├── lib/
│   ├── mquickjs.rb              # Main entry point
│   └── mquickjs/
│       ├── version.rb           # Version
│       ├── errors.rb            # Custom errors
│       └── ffi/
│           ├── bindings.rb      # FFI bindings
│           ├── sandbox.rb       # Sandbox implementation
│           └── libmquickjs.so   # Compiled library
├── build_mquickjs.sh            # Build script
├── test_mquickjs.rb             # Test suite
└── README.md                    # This file
```

### Value Conversion

JavaScript values are automatically converted to Ruby:

| JavaScript | Ruby |
|------------|------|
| `null` | `nil` |
| `undefined` | `nil` |
| `true` / `false` | `true` / `false` |
| Numbers | `Integer` or `Float` |
| Strings | `String` (UTF-8) |
| Arrays | Limited support (use with caution) |
| Objects | Limited support (use with caution) |

## Testing

```bash
ruby test_mquickjs.rb
```

All 21 tests should pass:

- Simple arithmetic and operations
- String manipulation
- Loops and functions
- Error handling (syntax, runtime, timeout)
- Memory limits
- Type conversions

## Limitations

### Memory Requirements

- Minimum ~10KB needed to initialize stdlib
- Recommended minimum: 50KB for practical use
- Assertion failure if `< 1024` bytes

### JavaScript Subset

mquickjs implements a stricter ES5 subset. Notable differences:

- No `with` keyword
- No direct `eval()`
- Arrays cannot have holes
- No value boxing (`new Number(1)` not supported)
- Limited `Date` support (`Date.now()` only)
- Case folding in regex is ASCII-only

### Security Considerations

While mquickjs provides strong sandboxing:

1. **Bytecode vulnerability**: Only run trusted bytecode (not implemented here)
2. **DoS via memory**: Set appropriate limits for your use case
3. **DoS via CPU**: Timeout enforcement has small overhead
4. **No network isolation**: Not implemented yet (see Roadmap)

## Roadmap

### Native Extension Version

For better performance and control:

- Direct C extension (no FFI overhead)
- Better error stack traces
- More efficient value conversion

### HTTP Support

Add secure HTTP capabilities:

```ruby
sandbox = MQuickJS::Sandbox.new(
  http_enabled: true,
  http_whitelist: ["https://api.github.com/*"]
)

result = sandbox.eval("fetch('https://api.github.com/users/octocat')")
```

Implementation considerations:
- Use libcurl or similar
- Strict whitelist enforcement
- Request/response size limits
- Timeout per request

## Contributing

This is an experimental project. Contributions welcome!

## License

MIT License (see API_DESIGN.md for full design rationale)

## Credits

- **mquickjs**: Fabrice Bellard and Charlie Gordon
- **Ruby FFI bindings**: This project
