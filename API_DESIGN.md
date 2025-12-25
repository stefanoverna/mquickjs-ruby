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

### Console Output Capture

```ruby
# Console.log output is captured automatically
result = MQuickJS.eval("console.log('Hello'); console.log('World'); 42")
result.value  # => 42
result.console_output  # => "Hello\nWorld\n"

# Configure console output limits
sandbox = MQuickJS::Sandbox.new(
  console_log_max_size: 10_000  # 10KB (default)
)

result = sandbox.eval("console.log('test'); 123")
result.value  # => 123
result.console_output  # => "test\n"

# Output is truncated if it exceeds the limit
code = "for (var i = 0; i < 10000; i++) console.log('x'.repeat(100))"
result = MQuickJS.eval(code)
result.console_output.bytesize  # => 10000 (truncated)
result.console_truncated?  # => true
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

### HTTP Support

```ruby
# Create sandbox with HTTP support
sandbox = MQuickJS::Sandbox.new(
  http_enabled: true,
  http_config: {
    whitelist: [
      "https://api.github.com/*",
      "https://httpbin.org/**"
    ],
    max_requests: 10,              # Max 10 HTTP calls per eval
    max_response_size: 1_048_576,  # 1MB response limit
    request_timeout: 5000,         # 5 second timeout
    block_private_ips: true        # Block internal networks
  }
)

# JavaScript API - Simple and synchronous
result = sandbox.eval(<<~JS)
  // GET request
  var response = http.get('https://api.github.com/users/octocat');

  if (response.ok) {
    var user = response.json();
    user.login;  // => "octocat"
  } else {
    'Error: ' + response.status;
  }
JS

# POST request
result = sandbox.eval(<<~JS)
  var data = JSON.stringify({ name: 'test', value: 123 });

  var response = http.post(
    'https://httpbin.org/post',
    data,
    { headers: { 'Content-Type': 'application/json' } }
  );

  response.status;  // => 200
JS

# Generic request method
result = sandbox.eval(<<~JS)
  var response = http.request({
    method: 'PUT',
    url: 'https://api.example.com/resource/123',
    headers: {
      'Authorization': 'Bearer token',
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ updated: true }),
    timeout: 3000
  });

  response.ok;
JS

# Blocked requests raise errors
begin
  sandbox.eval("http.get('https://evil.com/data')")
rescue MQuickJS::HTTPBlockedError => e
  puts "HTTP request blocked: not in whitelist"
end

begin
  sandbox.eval("http.get('http://192.168.1.1/admin')")
rescue MQuickJS::HTTPBlockedError => e
  puts "HTTP request blocked: private IP address"
end

# Access HTTP request log
result = sandbox.eval("http.get('https://api.github.com/users/octocat').status")
result.http_requests
# => [
#   {
#     method: 'GET',
#     url: 'https://api.github.com/users/octocat',
#     status: 200,
#     duration_ms: 145,
#     request_size: 256,
#     response_size: 1024
#   }
# ]
```

#### HTTP Security Features

1. **Domain Whitelist**: Only approved URLs can be accessed
2. **IP Blocking**: Private networks, localhost, and cloud metadata blocked
3. **Size Limits**: Request and response size limits prevent memory exhaustion
4. **Rate Limiting**: Max requests per evaluation prevents abuse
5. **Timeout Control**: Each request has a timeout to prevent hanging
6. **No Redirects**: Redirect following disabled by default to prevent bypass
7. **Method Control**: Restrict allowed HTTP methods (GET, POST, etc.)
8. **Header Sanitization**: Dangerous headers are filtered

See `HTTP_SECURITY_DESIGN.md` for complete threat model and implementation details.
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
