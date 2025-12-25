# MQuickJS Ruby Sandbox API Design

## Core Principles

1. **Simple, consistent API** - Same interface for FFI and native extension versions
2. **Safe by default** - Memory and CPU limits enforced
3. **Isolated execution** - No filesystem or network access unless explicitly allowed
4. **Clear error handling** - Distinguish between JS errors and sandbox violations

## API Design

### Basic Usage

```ruby
require 'mquickjs'

# Simple one-shot evaluation
result = MQuickJS.eval("1 + 2 + 3")
# => 6

result = MQuickJS.eval("'hello'.toUpperCase()")
# => "HELLO"

# With custom limits
result = MQuickJS.eval(
  "var sum = 0; for (var i = 0; i < 100; i++) sum += i; sum",
  memory_limit: 10_000,    # 10KB memory limit
  timeout_ms: 1000         # 1 second timeout
)
# => 4950
```

### Reusable Sandbox

```ruby
# Create a reusable sandbox
sandbox = MQuickJS::Sandbox.new(
  memory_limit: 50_000,  # 50KB (default)
  timeout_ms: 5000       # 5 seconds (default)
)

# Evaluate code multiple times
result1 = sandbox.eval("2 + 2")
# => 4

result2 = sandbox.eval("Math.sqrt(16)")
# => 4.0

# Each eval is isolated - no shared state
result3 = sandbox.eval("typeof x")
# => "undefined"
```

### Error Handling

```ruby
# JavaScript errors
begin
  MQuickJS.eval("throw new Error('oops')")
rescue MQuickJS::JavaScriptError => e
  puts e.message  # => "Error: oops"
  puts e.stack    # => JavaScript stack trace
end

# Syntax errors
begin
  MQuickJS.eval("var x = ")
rescue MQuickJS::SyntaxError => e
  puts e.message
end

# Memory limit exceeded
begin
  MQuickJS.eval(
    "var arr = []; while(true) arr.push(new Array(1000))",
    memory_limit: 1000
  )
rescue MQuickJS::MemoryLimitError => e
  puts "Out of memory"
end

# Timeout
begin
  MQuickJS.eval(
    "while(true) {}",
    timeout_ms: 100
  )
rescue MQuickJS::TimeoutError => e
  puts "Execution timeout"
end
```

### HTTP Support (Phase 2)

```ruby
# Create sandbox with HTTP support
sandbox = MQuickJS::Sandbox.new(
  http_enabled: true,
  http_whitelist: [
    "https://api.github.com/*",
    "https://httpbin.org/*"
  ]
)

# JavaScript can now make HTTP requests
result = sandbox.eval(<<~JS)
  var response = fetch('https://api.github.com/users/octocat');
  JSON.parse(response).login;
JS
# => "octocat"

# Blocked request
begin
  sandbox.eval("fetch('https://evil.com/data')")
rescue MQuickJS::HTTPBlockedError => e
  puts "HTTP request blocked"
end
```

## Implementation Details

### Default Limits

- **Memory limit**: 50KB (sufficient for most use cases)
- **Timeout**: 5000ms (5 seconds)
- **HTTP**: Disabled by default

### Return Types

JavaScript values are converted to Ruby types:
- `null` → `nil`
- `undefined` → `nil`
- Booleans → `true`/`false`
- Numbers → `Integer` or `Float`
- Strings → `String` (UTF-8)
- Arrays → `Array`
- Objects → `Hash`

### Sandboxing Features

1. **Memory isolation**: Fixed memory buffer, no access to system malloc
2. **CPU limiting**: Interrupt handler for timeout enforcement
3. **No I/O**: No file, network, or system access by default
4. **Stricter mode**: Dangerous JS features disabled (with, eval, etc.)

## Files Structure

```
lib/
  mquickjs.rb              # Main entry point
  mquickjs/
    version.rb             # Version constant
    sandbox.rb             # Sandbox class
    errors.rb              # Custom error classes
    ffi/                   # FFI implementation
      bindings.rb          # FFI bindings
      sandbox.rb           # FFI sandbox impl
    native/                # C extension implementation (future)
      mquickjs_native.so   # Compiled extension

ext/
  mquickjs/
    extconf.rb            # Extension build config
    mquickjs_ext.c        # C extension code
```
