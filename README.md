# MQuickJS - JavaScript Sandbox for Ruby

[![Gem Version](https://badge.fury.io/rb/mquickjs.svg)](https://badge.fury.io/rb/mquickjs)
[![Build Status](https://github.com/stefanoverna/mquickjs-ruby/workflows/CI/badge.svg)](https://github.com/stefanoverna/mquickjs-ruby/actions)

**MQuickJS** provides a JavaScript execution environment for Ruby applications with resource controls and isolation features. Built on [MicroQuickJS](https://bellard.org/mquickjs/) (a minimal QuickJS engine by Fabrice Bellard), it offers strict memory limits, CPU timeouts, and sandboxed execution.

Useful for evaluating user scripts, processing webhooks, executing templates, or building plugin systems in **trusted environments** or with **additional security measures**.

## Security Notice

**IMPORTANT:** This gem is built on MicroQuickJS, a young and minimal JavaScript engine that may contain security vulnerabilities. The sandboxing and resource limits provided by this gem are defense-in-depth measures, not a complete security solution.

**Use this gem ONLY if:**
- You are executing **trusted code** from known, vetted sources
- OR you are using **additional isolation** such as:
  - Running inside Docker containers with restricted capabilities
  - Using security sandboxes like [sandbox-runtime](https://github.com/anthropic-experimental/sandbox-runtime)
  - Operating system-level isolation (VMs, gVisor, Firecracker, etc.)

**DO NOT use this gem to execute untrusted JavaScript code directly in production without additional security layers.** No JavaScript engine sandboxing alone should be considered sufficient for hostile code execution.

## Table of Contents

- [Security Notice](#security-notice)
- [Table of Contents](#table-of-contents)
- [Features](#features)
  - [Defense-in-Depth Features](#defense-in-depth-features)
  - [Production-Ready](#production-ready)
- [Installation](#installation)
  - [System Requirements](#system-requirements)
  - [From RubyGems](#from-rubygems)
  - [From Source](#from-source)
    - [How the Build Works](#how-the-build-works)
- [Quick Start](#quick-start)
- [Usage Guide](#usage-guide)
  - [Basic Execution](#basic-execution)
  - [Passing Data to Scripts](#passing-data-to-scripts)
  - [Memory \& CPU Limits](#memory--cpu-limits)
  - [Console Output](#console-output)
  - [HTTP Requests](#http-requests)
    - [HTTP Configuration Options](#http-configuration-options)
    - [Response Properties](#response-properties)
- [JavaScript Limitations](#javascript-limitations)
  - [Language Features](#language-features)
    - [Supported (ES5-ish)](#supported-es5-ish)
    - [Not Supported](#not-supported)
  - [Available Standard Library](#available-standard-library)
  - [Code Examples](#code-examples)
    - [Good (Will Work)](#good-will-work)
    - [Bad (Will Not Work)](#bad-will-not-work)
  - [Workarounds](#workarounds)
- [Security Guardrails](#security-guardrails)
  - [Memory Safety](#memory-safety)
    - [Fixed Memory Allocation](#fixed-memory-allocation)
  - [CPU Protection](#cpu-protection)
    - [Execution Timeout](#execution-timeout)
  - [Console Output Limits](#console-output-limits)
    - [Size Restriction](#size-restriction)
  - [HTTP Security](#http-security)
    - [URL Allowlist](#url-allowlist)
    - [URL Denylist](#url-denylist)
    - [IP Address Blocking](#ip-address-blocking)
    - [Rate Limiting](#rate-limiting)
    - [Request Timeouts and Size Limits](#request-timeouts-and-size-limits)
    - [Complete HTTP Security Example](#complete-http-security-example)
  - [Sandboxing](#sandboxing)
    - [No File System Access](#no-file-system-access)
    - [No Network Access](#no-network-access)
    - [No Process Access](#no-process-access)
    - [Isolated Global Scope](#isolated-global-scope)
  - [Error Handling](#error-handling)
    - [MQuickJS::SyntaxError](#mquickjssyntaxerror)
    - [MQuickJS::JavaScriptError](#mquickjsjavascripterror)
- [API Reference](#api-reference)
  - [MQuickJS.eval(code, options = {})](#mquickjsevalcode-options--)
  - [MQuickJS::Sandbox.new(options = {})](#mquickjssandboxnewoptions--)
  - [Sandbox#eval(code)](#sandboxevalcode)
  - [Sandbox#set\_variable(name, value)](#sandboxset_variablename-value)
  - [MQuickJS::Result](#mquickjsresult)
- [Performance](#performance)
  - [Running Benchmarks](#running-benchmarks)
  - [Benchmark Results](#benchmark-results)
    - [Simple Operations (1000 iterations)](#simple-operations-1000-iterations)
    - [Computation (100 iterations)](#computation-100-iterations)
    - [JSON Operations (1000 iterations)](#json-operations-1000-iterations)
    - [Array Operations (500 iterations)](#array-operations-500-iterations)
    - [Sandbox Overhead (1000 iterations)](#sandbox-overhead-1000-iterations)
  - [Performance Characteristics](#performance-characteristics)
  - [Optimization Tips](#optimization-tips)
- [Contributing](#contributing)
  - [Development Setup](#development-setup)
  - [Running Tests](#running-tests)
- [License](#license)
- [Credits](#credits)
- [Security Recommendations](#security-recommendations)
  - [When to Use Additional Isolation](#when-to-use-additional-isolation)
  - [Threat Model](#threat-model)
  - [Reporting Security Issues](#reporting-security-issues)

## Features

### Defense-in-Depth Features

- **Strict Memory Limits** - Fixed memory allocation, no dynamic growth
- **CPU Timeout Enforcement** - Configurable execution time limits
- **Sandboxed Execution** - Isolated from file system and network (within the JavaScript engine)
- **Console Output Limits** - Prevent memory exhaustion via console.log
- **HTTP Security Controls** - Allowlist/denylist, rate limiting, IP blocking
- **No Dangerous APIs** - No eval(), no file I/O, no arbitrary code loading

### Production-Ready

- **Native C Extension** - High performance with minimal overhead
- **Zero Runtime Dependencies** - Pure Ruby + C, no external services
- **Comprehensive Test Coverage** - 129+ tests ensuring reliability
- **Thread-Safe** - Safe for concurrent execution
- **Memory Efficient** - Minimal memory footprint (50KB default)

## Installation

### System Requirements

- Ruby development headers
- C compiler (`gcc` or `clang`)
- `make`

**Ubuntu/Debian:**
```bash
sudo apt-get install ruby-dev build-essential
```

**macOS:**
```bash
xcode-select --install
```

### From RubyGems

Add to your Gemfile:

```ruby
gem 'mquickjs'
```

Then run:

```bash
bundle install
```

Or install directly:

```bash
gem install mquickjs
```

### From Source

All mquickjs source files are included in the repository - no separate checkout needed.

```bash
# Clone the repository
git clone https://github.com/stefanoverna/mquickjs-ruby.git
cd mquickjs-ruby

# Build and test
rake
```

This will:
- Clean previous builds
- Compile the extension
- Run all tests

#### How the Build Works

The native extension build process has two stages:

1. **Generate JavaScript stdlib** - A host tool (`mqjs_stdlib_gen`) is compiled from `mqjs_stdlib.c` and `mquickjs_build.c`, then executed to generate `mqjs_stdlib.h`. This header contains the JavaScript standard library (Object, Array, String, etc.) as pre-compiled binary data optimized for the target platform.

2. **Compile Ruby extension** - The generated header is included when building the native extension (`mquickjs_native.so`).

This ensures the JavaScript runtime is correctly compiled for your specific platform and architecture.

## Quick Start

```ruby
require 'mquickjs'

# Simple evaluation
result = MQuickJS.eval("2 + 2")
puts result.value  # => 4

# With custom limits
sandbox = MQuickJS::Sandbox.new(
  memory_limit: 100_000,      # 100KB memory limit
  timeout_ms: 1000,            # 1 second timeout
  console_log_max_size: 50_000 # 50KB console output limit
)

# Run code
result = sandbox.eval(<<~JS)
  function fibonacci(n) {
    if (n <= 1) return n;
    return fibonacci(n - 1) + fibonacci(n - 2);
  }
  fibonacci(10);
JS

puts result.value           # => 55
puts result.console_output  # => (any console.log output)
```

## Usage Guide

### Basic Execution

```ruby
require 'mquickjs'

# One-shot evaluation (creates sandbox automatically)
result = MQuickJS.eval("Math.sqrt(16)")
result.value  # => 4.0

# Reusable sandbox
sandbox = MQuickJS::Sandbox.new
result = sandbox.eval("var x = 10; x * 2")
result.value  # => 20

# Access console output
result = sandbox.eval('console.log("Hello"); 42')
result.value           # => 42
result.console_output  # => "Hello\n"
```

### Passing Data to Scripts

Use `set_variable()` to pass Ruby data directly to JavaScript:

```ruby
sandbox = MQuickJS::Sandbox.new

# Set variables
sandbox.set_variable("user", { name: "Alice", age: 30 })
sandbox.set_variable("items", [1, 2, 3, 4, 5])

# Use them in JavaScript
result = sandbox.eval("user.name + ' is ' + user.age")
result.value  # => "Alice is 30"

result = sandbox.eval("items.reduce(function(sum, n) { return sum + n }, 0)")
result.value  # => 15
```

**Supported types:**
- Primitives: `nil`, `true`, `false`, integers, floats, strings, symbols
- Arrays (including nested arrays)
- Hashes (including nested hashes)

Variables persist across `eval()` calls in the same sandbox. See [test/set_variable_test.rb](test/set_variable_test.rb) for comprehensive usage examples.

### Memory & CPU Limits

```ruby
# Configure resource limits
sandbox = MQuickJS::Sandbox.new(
  memory_limit: 50_000,  # Bytes - default: 50,000 (50KB)
  timeout_ms: 5000       # Milliseconds - default: 5,000 (5 seconds)
)

# Memory limit exceeded
begin
  sandbox.eval('var arr = []; while(true) arr.push(new Array(1000))')
rescue MQuickJS::MemoryLimitError => e
  puts "Out of memory: #{e.message}"
end

# Timeout exceeded
begin
  sandbox.eval('while(true) {}')  # Infinite loop
rescue MQuickJS::TimeoutError => e
  puts "Execution timeout: #{e.message}"
end

# Syntax errors
begin
  sandbox.eval('var x = ;')  # Invalid syntax
rescue MQuickJS::SyntaxError => e
  puts "Syntax error: #{e.message}"
end

# Runtime errors
begin
  sandbox.eval('throw new Error("Something went wrong")')
rescue MQuickJS::JavaScriptError => e
  puts "JavaScript error: #{e.message}"
end
```

### Console Output

```ruby
sandbox = MQuickJS::Sandbox.new(console_log_max_size: 10_000)

result = sandbox.eval(<<~JS)
  console.log("Starting calculation...");
  var sum = 0;
  for (var i = 0; i < 100; i++) {
    sum += i;
  }
  console.log("Sum:", sum);
  sum;
JS

puts result.value           # => 4950
puts result.console_output  # => "Starting calculation...\nSum: 4950\n"
puts result.console_truncated?  # => false (output fit within limit)
```

### HTTP Requests

MQuickJS provides a native `fetch()` function for JavaScript. Enable it by passing HTTP configuration when creating the sandbox:

```ruby
require 'mquickjs'

sandbox = MQuickJS::Sandbox.new(
  http: {
    allowlist: ['https://api.github.com/**']
  }
)

# Now fetch() works in JavaScript
result = sandbox.eval(<<~JS)
  var response = fetch('https://api.github.com/users/octocat');
  JSON.parse(response.body).login;
JS

result.value  # => "octocat"
```

#### HTTP Configuration Options

```ruby
sandbox = MQuickJS::Sandbox.new(
  http: {
    # URL allowlist (only these patterns allowed) - use ONE of allowlist or denylist
    allowlist: ['https://api.github.com/**', 'https://api.stripe.com/v1/**'],

    # OR URL denylist (block these patterns, allow everything else)
    # denylist: ['https://evil.com/**', 'https://*.malware.net/**'],

    # Security options
    block_private_ips: true,                    # Block private/local IPs (default: true)
    allowed_ports: [80, 443],                   # Allowed ports (default: [80, 443])
    allowed_methods: ['GET', 'POST'],           # HTTP methods allowed (default: GET, POST, PUT, DELETE, PATCH, HEAD)

    # Rate limiting
    max_requests: 10,                           # Max requests per eval (default: 10)

    # Size limits
    max_request_size: 1_048_576,                # Max request body size (default: 1MB)
    max_response_size: 1_048_576,               # Max response size (default: 1MB)

    # Timeout
    request_timeout: 5000                       # Request timeout in ms (default: 5000)
  }
)
```

#### Response Properties

The `fetch()` function returns a response object similar to the standard [Fetch API](https://developer.mozilla.org/en-US/docs/Web/API/Response), but simplified for synchronous use. Unlike the browser's async `fetch()`, this version returns the response directly (no Promises) and provides the body as a string property instead of requiring `.text()` or `.json()` methods.

Available properties:

| Property     | Type    | Description                                    |
| ------------ | ------- | ---------------------------------------------- |
| `status`     | Integer | HTTP status code (e.g., 200, 404, 500)         |
| `statusText` | String  | HTTP status message (e.g., "OK", "Not Found")  |
| `ok`         | Boolean | `true` if status is 200-299, `false` otherwise |
| `body`       | String  | Response body as a string                      |
| `headers`    | Object  | Response headers as key-value pairs            |

```javascript
var response = fetch('https://api.example.com/users');

response.status;      // 200
response.statusText;  // "OK"
response.ok;          // true
response.body;        // '{"users": [...]}'
response.headers;     // {"content-type": "application/json", ...}

// Parse JSON response
var data = JSON.parse(response.body);
```

## JavaScript Limitations

MQuickJS uses [MicroQuickJS](https://bellard.org/mquickjs/), an extremely minimal JavaScript engine designed for embedded systems. This imposes several limitations:

### Language Features

#### Supported (ES5-ish)

- Variables: `var` declarations
- Functions: function declarations and expressions
- Objects and arrays
- Loops: `for`, `while`, `do-while`
- Conditionals: `if`, `else`, `switch`
- Operators: arithmetic, logical, bitwise
- `typeof`, `instanceof`
- `try`/`catch`/`finally`
- Regular expressions (basic)

#### Not Supported

- **No ES6+ features:**
  - No `let`, `const`
  - No arrow functions `() =>`
  - No template literals `` `string ${var}` ``
  - No destructuring `{a, b} = obj`
  - No spread operator `...`
  - No classes (use prototypes)
  - No `Symbol`, `Map`, `Set`, `WeakMap`, `WeakSet`

- **No async/await or Promises:**
  - All code executes synchronously
  - No `async`/`await`
  - No `Promise`
  - No `setTimeout`/`setInterval`

- **No module system:**
  - No `import`/`export`
  - No `require()`
  - No dynamic `import()`

- **No Node.js/Browser APIs:**
  - No `process`, `Buffer`, `fs`, `path`, etc.
  - No DOM (`document`, `window`, etc.)
  - No `XMLHttpRequest` (use `fetch()` with `http_callback`)
  - No `localStorage`, `sessionStorage`

### Available Standard Library

MicroQuickJS includes a minimal standard library:

```javascript
// Math object
Math.sqrt(16)    // Available
Math.random()    // Available
Math.floor(3.7)  // Available

// JSON
JSON.parse('{"a":1}')     // Available
JSON.stringify({a: 1})    // Available

// String methods
"hello".toUpperCase()     // Available
"hello".substring(0, 2)   // Available
"hello".split("")         // Available

// Array methods
[1,2,3].map(function(x) { return x * 2 })  // Available
[1,2,3].filter(function(x) { return x > 1 })  // Available
[1,2,3].reduce(function(a,b) { return a + b }, 0)  // Available

// Object methods
Object.keys({a:1, b:2})   // Available

// Date (basic - no new Date())
Date.now()                // Available

// console
console.log("message")    // Available (captured by sandbox)

// Global functions
parseInt("42")            // Available
parseFloat("3.14")        // Available
isNaN(NaN)                // Available
```

### Code Examples

#### Good (Will Work)

```javascript
// Use var, not let/const
var users = [
  {name: "Alice", age: 30},
  {name: "Bob", age: 25}
];

// Use function expressions, not arrows
var adults = users.filter(function(user) {
  return user.age >= 18;
});

// Use string concatenation, not template literals
var message = "Found " + adults.length + " adults";

// Use Object.keys for iteration
var obj = {a: 1, b: 2, c: 3};
var sum = 0;
Object.keys(obj).forEach(function(key) {
  sum += obj[key];
});
```

#### Bad (Will Not Work)

```javascript
// let/const not supported
let x = 10;        // SyntaxError
const y = 20;      // SyntaxError

// Arrow functions not supported
[1,2,3].map(x => x * 2);  // SyntaxError

// Template literals not supported
var name = "World";
console.log(`Hello ${name}`);  // SyntaxError

// Destructuring not supported
var {a, b} = {a: 1, b: 2};  // SyntaxError

// Async/await not supported
async function fetchData() {  // SyntaxError
  await fetch('/api/data');
}

// Classes not supported
class User {  // SyntaxError
  constructor(name) { this.name = name; }
}

// Promises not supported
new Promise(function(resolve) {  // Error: Promise not defined
  resolve(42);
});
```

### Workarounds

For common ES6+ patterns, use ES5 equivalents:

```javascript
// Instead of: const add = (a, b) => a + b;
var add = function(a, b) { return a + b; };

// Instead of: `Hello ${name}`
var name = "World";
var greeting = "Hello " + name;

// Instead of: const {x, y} = point;
var point = {x: 10, y: 20};
var x = point.x;
var y = point.y;

// Instead of: [...array1, ...array2]
var combined = array1.concat(array2);

// Instead of: class with constructor
function User(name) {
  this.name = name;
}
User.prototype.greet = function() {
  return "Hello, " + this.name;
};
```

## Security Guardrails

MQuickJS implements multiple layers of defense-in-depth security controls. While these features provide important resource limits and isolation, they should not be relied upon as the sole security mechanism for executing untrusted code.

### Memory Safety

#### Fixed Memory Allocation

```ruby
sandbox = MQuickJS::Sandbox.new(memory_limit: 50_000)  # 50KB fixed buffer
```

**How it works:**
- Allocates a fixed-size memory buffer at initialization
- No dynamic memory allocation during execution
- All JavaScript objects must fit within this buffer
- Automatically raises `MemoryLimitError` when exceeded

**What it prevents:**
- Memory exhaustion attacks
- Unbounded memory growth
- Heap spray attacks
- Memory-based denial of service

**Example protection:**

```ruby
sandbox = MQuickJS::Sandbox.new(memory_limit: 10_000)  # 10KB only

# This will fail - tries to allocate too much memory
begin
  sandbox.eval('var big = new Array(100000); big.fill(0)')
rescue MQuickJS::MemoryLimitError
  puts "Memory limit protected us!"
end
```

### CPU Protection

#### Execution Timeout

```ruby
sandbox = MQuickJS::Sandbox.new(timeout_ms: 1000)  # 1 second max
```

**How it works:**
- Starts a timer when `eval()` is called
- Periodically checks elapsed time during execution
- Immediately terminates execution if timeout exceeded
- Raises `TimeoutError` with no memory leaks

**What it prevents:**
- Infinite loops
- CPU-intensive attacks
- Algorithmic complexity attacks (e.g., expensive regex)
- Hanging execution

**Example protection:**

```ruby
sandbox = MQuickJS::Sandbox.new(timeout_ms: 100)  # 100ms max

# Infinite loop - will timeout
begin
  sandbox.eval('while(true) {}')
rescue MQuickJS::TimeoutError
  puts "Timeout protection worked!"
end

# Expensive computation - will timeout
begin
  sandbox.eval('function fib(n) { return n <= 1 ? n : fib(n-1) + fib(n-2); } fib(100)')
rescue MQuickJS::TimeoutError
  puts "Prevented expensive computation!"
end
```

### Console Output Limits

#### Size Restriction

```ruby
sandbox = MQuickJS::Sandbox.new(console_log_max_size: 10_000)  # 10KB max
```

**How it works:**
- Captures all `console.log()`, `console.error()`, etc. calls
- Accumulates output in a fixed-size buffer
- Stops capturing when limit reached (sets `console_truncated` flag)
- Prevents memory exhaustion via console spam

**What it prevents:**
- Console output flooding
- Memory exhaustion through logging
- Log-based denial of service

**Example protection:**

```ruby
sandbox = MQuickJS::Sandbox.new(console_log_max_size: 100)

result = sandbox.eval(<<~JS)
  for (var i = 0; i < 1000; i++) {
    console.log("Spam spam spam spam spam spam");
  }
JS

puts result.console_truncated?  # => true (output exceeded limit)
puts result.console_output.length  # => ~100 bytes (truncated)
```

### HTTP Security

MQuickJS provides comprehensive HTTP security controls through the `http:` configuration option:

#### URL Allowlist

Use an allowlist when you want to restrict fetch to specific trusted APIs:

```ruby
sandbox = MQuickJS::Sandbox.new(
  http: {
    allowlist: [
      'https://api.github.com/**',       # Allow GitHub API
      'https://api.example.com/public/**' # Allow specific endpoints
    ]
  }
)
```

**Supports:**
- Exact matches: `https://api.example.com/users`
- Wildcards: `https://api.example.com/**`
- Path patterns: `https://api.example.com/v*/users`
- Subdomain patterns: `https://*.example.com/api/*`

**Blocks:**
- All non-allowed URLs
- Protocol changes (http:// if only https:// allowed)
- Subdomain variations (unless using wildcard)

#### URL Denylist

Use a denylist when you want to allow most URLs but block specific domains:

```ruby
sandbox = MQuickJS::Sandbox.new(
  http: {
    denylist: [
      'https://evil.com/**',           # Block evil.com
      'https://*.malware.net/**'       # Block all malware.net subdomains
    ]
  }
)
```

**Behavior:**
- All URLs are allowed EXCEPT those matching denylist patterns
- Cannot be used together with allowlist (choose one)

**Use cases:**
- When you need broad internet access with specific exclusions
- Blocking known malicious domains
- Preventing access to competitor APIs

#### IP Address Blocking

By default, private and local IP addresses are blocked:

```ruby
sandbox = MQuickJS::Sandbox.new(
  http: {
    allowlist: ['https://api.example.com/**'],
    block_private_ips: true               # Block private IPs (default: true)
  }
)
```

**Automatically blocked when `block_private_ips: true`:**
- `127.0.0.0/8` - Loopback
- `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16` - Private networks
- `169.254.0.0/16` - Link-local (AWS metadata)
- `::1/128`, `fe80::/10` - IPv6 loopback and link-local

**Prevents:**
- SSRF (Server-Side Request Forgery) attacks
- Access to internal services
- Metadata endpoint abuse (cloud providers)
- Local network scanning

**DNS rebinding protection:**
- Resolves hostname to IP before request
- Checks IP against blocklist
- Rejects if IP is blocked

#### Rate Limiting

```ruby
sandbox = MQuickJS::Sandbox.new(
  http: {
    allowlist: ['https://api.example.com/**'],
    max_requests: 5    # Max requests per eval
  }
)
```

**How it works:**
- Counts HTTP requests per `eval()` call
- Raises `HTTPError` when limit exceeded
- Resets counter for each new evaluation

**Prevents:**
- HTTP flooding
- API quota exhaustion
- Denial of service via excessive requests

#### Request Timeouts and Size Limits

```ruby
sandbox = MQuickJS::Sandbox.new(
  http: {
    allowlist: ['https://api.example.com/**'],
    request_timeout: 3000,        # 3 second timeout
    max_request_size: 100_000,    # 100KB max request body
    max_response_size: 500_000    # 500KB max response
  }
)
```

**Prevents:**
- Hanging on slow servers
- Intentional delay attacks
- Memory exhaustion via large responses

#### Complete HTTP Security Example

```ruby
# Production-grade HTTP security configuration (allowlist mode)
sandbox = MQuickJS::Sandbox.new(
  memory_limit: 100_000,
  timeout_ms: 10_000,
  http: {
    # Only allow specific trusted APIs
    allowlist: [
      'https://api.github.com/**',
      'https://api.stripe.com/v1/**'
    ],

    # Strict limits
    max_requests: 5,
    request_timeout: 3000,
    max_response_size: 500_000,

    # Only allow GET and POST
    allowed_methods: ['GET', 'POST']
  }
)

# Or use denylist mode to block specific domains
sandbox_denylist = MQuickJS::Sandbox.new(
  http: {
    denylist: [
      'https://evil.com/**',
      'https://*.malware.net/**'
    ]
  }
)

# Safe execution with security controls
begin
  result = sandbox.eval("fetch('https://api.github.com/users/octocat').body")
rescue MQuickJS::HTTPError => e
  puts "HTTP security blocked request: #{e.message}"
end
```

### Sandboxing

#### No File System Access

- No `fs` module
- No `require()` or dynamic code loading
- No `eval()` or `Function()` constructor
- No access to Ruby environment variables

#### No Network Access

- No direct socket access
- No `XMLHttpRequest`
- `fetch()` only works via Ruby `http_callback` (you control all network access)
- No DNS queries (Ruby handles DNS in the callback)

#### No Process Access

- No `process` object
- No `child_process` or command execution
- No access to system calls
- No ability to spawn threads or processes

#### Isolated Global Scope

```ruby
# Each sandbox has completely isolated global scope
sandbox1 = MQuickJS::Sandbox.new
sandbox2 = MQuickJS::Sandbox.new

sandbox1.eval('var secret = "password123"')
sandbox2.eval('secret')  # => undefined (not accessible)
```

### Error Handling

MQuickJS provides specific exception classes for different error types:

```ruby
begin
  sandbox.eval(your_code)
rescue MQuickJS::SyntaxError => e
  # JavaScript syntax error
  puts "Invalid syntax: #{e.message}"
rescue MQuickJS::JavaScriptError => e
  # JavaScript runtime error (throw, ReferenceError, etc.)
  puts "Runtime error: #{e.message}"
rescue MQuickJS::MemoryLimitError => e
  # Memory limit exceeded
  puts "Out of memory: #{e.message}"
rescue MQuickJS::TimeoutError => e
  # Execution timeout
  puts "Timeout: #{e.message}"
rescue MQuickJS::HTTPError => e
  # HTTP security violation
  puts "HTTP error: #{e.message}"
end
```

#### MQuickJS::SyntaxError

Raised when JavaScript code contains a syntax error.

**Attributes:**

- `message` (String): The full error message, prefixed with `SyntaxError:` and a description
- `stack` (String): Location info showing where the syntax error occurred (line and column)

```ruby
begin
  sandbox.eval("var x = 1;\nvar y = 2;\nfunction broken() {")
rescue MQuickJS::SyntaxError => e
  puts e.message
  # => "SyntaxError: expecting '}'"

  puts e.stack
  # => "    at <eval>:3:20\n"
end
```

**Common syntax errors:**

```ruby
# Using unsupported ES6+ features
sandbox.eval("const x = 10")
# => SyntaxError: unexpected character in expression

sandbox.eval("let y = 20")
# => SyntaxError: unexpected character in expression

sandbox.eval("[1,2,3].map(x => x * 2)")
# => SyntaxError: unexpected character in expression

sandbox.eval("`template ${literal}`")
# => SyntaxError: unexpected character in expression

# Missing syntax elements
sandbox.eval("function() {}")
# => SyntaxError: function name expected
```

#### MQuickJS::JavaScriptError

Raised when JavaScript code throws an error at runtime. This includes explicit `throw` statements and built-in errors like `TypeError`, `ReferenceError`, etc.

**Attributes:**

- `message` (String): The full error message, including the error type and description
- `stack` (String): JavaScript stack trace showing the call chain with function names and line numbers

```ruby
begin
  sandbox.eval(<<~JS)
    function processUser(user) {
      return user.name.toUpperCase();
    }
    processUser(null);  // Will throw TypeError
  JS
rescue MQuickJS::JavaScriptError => e
  puts e.message
  # => "TypeError: cannot read property 'name' of null"

  puts e.stack
  # => "    at processUser (<eval>:2:19)\n    at <eval> (<eval>:4:4)\n"
end
```

**Stack trace example with nested calls:**

```ruby
begin
  sandbox.eval(<<~JS)
    function innerFunc() {
      throw new Error("something went wrong");
    }
    function outerFunc() {
      innerFunc();
    }
    outerFunc();
  JS
rescue MQuickJS::JavaScriptError => e
  puts "Error: #{e.message}"
  puts "Stack trace:"
  e.stack.each_line { |line| puts "  #{line}" }
  # Error: Error: something went wrong
  # Stack trace:
  #       at innerFunc (<eval>:2:18)
  #       at outerFunc (<eval>:5:6)
  #       at <eval> (<eval>:7:4)
end
```

**Common runtime errors:**

```ruby
# Accessing undefined variable
sandbox.eval("undefinedVariable")
# => ReferenceError: variable 'undefinedVariable' is not defined

# Accessing property of null
sandbox.eval("null.foo")
# => TypeError: cannot read property 'foo' of null

# Calling non-function
sandbox.eval("var x = {}; x.foo()")
# => TypeError: not a function

# Explicit throw
sandbox.eval("throw new Error('something went wrong')")
# => Error: something went wrong
```

**Error types captured as JavaScriptError:**

| JavaScript Error | Description                                                  |
| ---------------- | ------------------------------------------------------------ |
| `Error`          | Generic error from `throw new Error()`                       |
| `TypeError`      | Type mismatch (e.g., calling non-function, property of null) |
| `ReferenceError` | Accessing undefined variable                                 |
| `RangeError`     | Value out of allowed range                                   |
| `URIError`       | Malformed URI functions                                      |
| `EvalError`      | Error in eval() (rarely thrown)                              |
| `InternalError`  | Internal engine error                                        |

**Debugging tips:**

```ruby
begin
  sandbox.eval(user_code)
rescue MQuickJS::JavaScriptError => e
  # Parse the error type from the message
  error_type = e.message.split(':').first  # "TypeError", "ReferenceError", etc.

  case error_type
  when "TypeError"
    puts "Type error - check for null/undefined values or type mismatches"
  when "ReferenceError"
    puts "Undefined variable - check variable names and scope"
  when "RangeError"
    puts "Value out of range - check array indices or numeric values"
  else
    puts "JavaScript error: #{e.message}"
  end
end
```

**Custom error messages from JavaScript:**

```ruby
begin
  sandbox.eval(<<~JS)
    function validateAge(age) {
      if (typeof age !== 'number') {
        throw new TypeError('age must be a number, got ' + typeof age);
      }
      if (age < 0 || age > 150) {
        throw new RangeError('age must be between 0 and 150, got ' + age);
      }
      return age;
    }
    validateAge("twenty");
  JS
rescue MQuickJS::JavaScriptError => e
  puts e.message
  # => "TypeError: age must be a number, got string"
end
```

## API Reference

### MQuickJS.eval(code, options = {})

Convenience method for one-shot JavaScript evaluation.

**Parameters:**
- `code` (String): JavaScript code to execute
- `options` (Hash, optional):
  - `:memory_limit` (Integer): Memory limit in bytes (default: 50,000)
  - `:timeout_ms` (Integer): Timeout in milliseconds (default: 5,000)
  - `:http` (Hash): HTTP configuration to enable fetch() (see [HTTP Requests](#http-requests))

**Returns:** `MQuickJS::Result`

**Example:**
```ruby
result = MQuickJS.eval("2 + 2", memory_limit: 10_000, timeout_ms: 1000)

# With HTTP enabled (allowlist mode)
result = MQuickJS.eval(
  "fetch('https://api.example.com/data').body",
  http: { allowlist: ['https://api.example.com/**'] }
)

# With HTTP enabled (denylist mode)
result = MQuickJS.eval(
  "fetch('https://safe-api.com/data').body",
  http: { denylist: ['https://evil.com/**'] }
)
```

### MQuickJS::Sandbox.new(options = {})

Create a reusable JavaScript sandbox.

**Parameters:**
- `options` (Hash, optional):
  - `:memory_limit` (Integer): Memory limit in bytes (default: 50,000)
  - `:timeout_ms` (Integer): Timeout in milliseconds (default: 5,000)
  - `:console_log_max_size` (Integer): Console output limit (default: 10,000)
  - `:http` (Hash): HTTP configuration to enable fetch() (see [HTTP Requests](#http-requests))

**Example:**
```ruby
sandbox = MQuickJS::Sandbox.new(
  memory_limit: 100_000,
  timeout_ms: 2000,
  console_log_max_size: 20_000,
  http: { allowlist: ['https://api.example.com/**'] }
)

# Or with denylist
sandbox = MQuickJS::Sandbox.new(
  http: { denylist: ['https://evil.com/**', 'https://*.malware.net/**'] }
)
```

### Sandbox#eval(code)

Execute JavaScript code in the sandbox.

**Parameters:**
- `code` (String): JavaScript code to execute

**Returns:** `MQuickJS::Result`

**Raises:**
- `MQuickJS::SyntaxError`: Invalid JavaScript syntax
- `MQuickJS::JavaScriptError`: JavaScript runtime error
- `MQuickJS::MemoryLimitError`: Memory limit exceeded
- `MQuickJS::TimeoutError`: Execution timeout

**Example:**
```ruby
result = sandbox.eval("Math.sqrt(16)")
```

### Sandbox#set_variable(name, value)

Set a global variable in the sandbox from Ruby.

**Parameters:**
- `name` (String): Variable name
- `value` (Object): Ruby value (nil, boolean, number, string, array, or hash)

**Example:**
```ruby
sandbox.set_variable("config", { debug: true, max_items: 100 })
sandbox.eval("config.debug")  # => true
```

### MQuickJS::Result

Result object returned by `eval()` operations.

**Attributes:**
- `value`: The return value of the JavaScript code (converted to Ruby)
- `console_output` (String): Captured console.log output
- `console_truncated?` (Boolean): Whether console output was truncated

**Example:**
```ruby
result = sandbox.eval('console.log("test"); 42')
result.value           # => 42
result.console_output  # => "test\n"
result.console_truncated?  # => false
```

## Performance

### Running Benchmarks

The gem includes a comprehensive benchmark suite:

```bash
# Run all benchmarks
rake benchmark

# Run individual benchmarks
rake benchmark:simple      # Simple operations
rake benchmark:computation # Fibonacci, factorial, primes
rake benchmark:json        # JSON operations
rake benchmark:array       # Array methods
rake benchmark:overhead    # Sandbox creation overhead
rake benchmark:memory      # Memory limits
rake benchmark:console     # Console output
```

### Benchmark Results

**Test Environment:** Ruby 3.3.6, Linux x86_64

#### Simple Operations (1000 iterations)
```
                                     user     system      total        real
Arithmetic (2 + 2):              0.000000   0.000000   0.000000 (  0.001364)
String concatenation:            0.000000   0.000000   0.000000 (  0.001833)
String methods:                  0.000000   0.000000   0.000000 (  0.001996)
Math operations:                 0.000000   0.000000   0.000000 (  0.004378)
Variable assignment:             0.010000   0.000000   0.010000 (  0.002710)
Function call:                   0.000000   0.000000   0.000000 (  0.003842)
Boolean operations:              0.000000   0.000000   0.000000 (  0.002071)
Typeof operator:                 0.010000   0.000000   0.010000 (  0.002301)
```

**Performance:** ~1-4μs per simple operation, ideal for high-throughput scenarios.

#### Computation (100 iterations)
```
                                     user     system      total        real
Fibonacci (recursive, n=10):     0.000000   0.000000   0.000000 (  0.001399)
Fibonacci (recursive, n=15):     0.000000   0.000000   0.000000 (  0.004037)
Fibonacci (iterative, n=30):     0.000000   0.000000   0.000000 (  0.001167)
Factorial (n=20):                0.000000   0.000000   0.000000 (  0.000769)
Array sum (1000 elements):       0.010000   0.000000   0.010000 (  0.009723)
Prime check (n=1000):            0.000000   0.000000   0.000000 (  0.000894)
```

**Performance:** Handles complex computations efficiently. Recursive fibonacci(15) takes ~40μs, iterative approach is 3x faster.

#### JSON Operations (1000 iterations)
```
                                     user     system      total        real
JSON.parse (simple):             0.010000   0.000000   0.010000 (  0.003024)
JSON.parse (nested):             0.000000   0.000000   0.000000 (  0.005803)
JSON.parse (array):              0.000000   0.000000   0.000000 (  0.003840)
JSON.stringify (simple):         0.010000   0.000000   0.010000 (  0.003667)
JSON.stringify (nested):         0.010000   0.000000   0.010000 (  0.008326)
JSON round-trip:                 0.000000   0.000000   0.000000 (  0.008575)
```

**Performance:** ~3-9μs per JSON operation. Excellent for webhook processing and data transformations.

#### Array Operations (500 iterations)
```
                                     user     system      total        real
Array.map (100 elements):        0.010000   0.000000   0.010000 (  0.012407)
Array.filter (100 elements):     0.010000   0.000000   0.010000 (  0.009904)
Array.reduce (100 elements):     0.010000   0.000000   0.010000 (  0.008172)
Array.forEach (100 elements):    0.010000   0.000000   0.010000 (  0.008253)
Array.sort (100 elements):       0.040000   0.000000   0.040000 (  0.044416)
Array.concat:                    0.000000   0.000000   0.000000 (  0.003996)
Array.slice:                     0.000000   0.000000   0.000000 (  0.003042)
Array.join:                      0.000000   0.000000   0.000000 (  0.002375)
Array chaining:                  0.010000   0.000000   0.010000 (  0.010141)
```

**Performance:** Array methods run in 8-25μs for 100 elements. Sorting is slower (~89μs) but still performant.

#### Sandbox Overhead (1000 iterations)
```
                                     user     system      total        real
Sandbox creation:                0.010000   0.010000   0.020000 (  0.028610)
Sandbox with custom limits:      0.020000   0.020000   0.040000 (  0.045994)
MQuickJS.eval (creates sandbox):  0.030000   0.000000   0.030000 (  0.031370)

Comparison: Reuse vs Create New
  Reuse sandbox (1000 evals):    0.010000   0.000000   0.010000 (  0.010108)
  New sandbox each time:         0.000000   0.000000   0.000000 (  0.005082)
```

**Performance:** Sandbox creation takes ~29-46μs. Reusing sandboxes is ~3x faster for repeated evaluations (10μs vs 31μs per eval).

### Performance Characteristics

- **Sandbox creation:** ~29μs (reusable for multiple evaluations)
- **Simple eval:** ~1-4μs per operation
- **JSON operations:** ~3-9μs per operation
- **Array operations:** ~8-25μs for 100 elements
- **Memory overhead:** Minimal (sandboxes are lightweight)
- **Thread-safe:** Yes (each sandbox is independent)

### Optimization Tips

1. **Reuse sandboxes** when possible:
   ```ruby
   # Good: Reuse sandbox
   sandbox = MQuickJS::Sandbox.new
   1000.times { sandbox.eval(code) }

   # Less efficient: Create new sandbox each time
   1000.times { MQuickJS.eval(code) }
   ```

2. **Batch operations** in JavaScript when possible:
   ```ruby
   # More efficient: Process array in JavaScript
   sandbox.eval('[1,2,3,4,5].map(function(x) { return x * 2 })')

   # Less efficient: Multiple Ruby calls
   [1,2,3,4,5].map { |x| sandbox.eval("#{x} * 2").value }
   ```

3. **Use appropriate memory limits:**
   ```ruby
   # Small scripts: use minimal memory
   MQuickJS::Sandbox.new(memory_limit: 10_000)  # 10KB

   # Complex operations: allocate more
   MQuickJS::Sandbox.new(memory_limit: 500_000)  # 500KB
   ```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/stefanoverna/mquickjs-ruby.

### Development Setup

```bash
# Clone the repository
git clone https://github.com/stefanoverna/mquickjs-ruby.git
cd mquickjs-ruby

# Install dependencies
bundle install

# Build and test
rake
```

### Running Tests

```bash
# Run all tests
bundle exec rake test

# Run specific test file
ruby -Ilib test/mquickjs_test.rb

# Run with verbose output
ruby -Ilib test/mquickjs_test.rb --verbose
```

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Credits

- **MicroQuickJS**: Created by Fabrice Bellard - https://bellard.org/mquickjs/
- **QuickJS**: The original JavaScript engine - https://bellard.org/quickjs/

## Security Recommendations

### When to Use Additional Isolation

For untrusted code execution, **always** use additional security layers beyond this gem:

**Option 1: Docker Containers**
```bash
# Run with restricted capabilities and no network
docker run --rm --cap-drop=ALL --network=none \
  -v $(pwd):/app ruby:3.3 \
  ruby /app/your_script.rb
```

**Option 2: Anthropic Sandbox Runtime**
- [sandbox-runtime](https://github.com/anthropic-experimental/sandbox-runtime) provides secure Python/JavaScript sandboxing
- Designed specifically for LLM-generated code execution

**Option 3: VM-based Isolation**
- gVisor for lightweight VM isolation
- Firecracker for microVM isolation
- Traditional VMs for maximum isolation

### Threat Model

**What this gem protects against:**
- Accidental infinite loops (via timeout)
- Memory exhaustion (via memory limits)
- Excessive console output
- Basic SSRF attempts (via HTTP allowlist/denylist and IP blocking)

**What this gem does NOT protect against:**
- JavaScript engine vulnerabilities (RCE, sandbox escapes)
- Side-channel attacks
- Timing attacks
- CPU-based DoS (partially mitigated by timeout)
- All classes of sophisticated attacks

### Reporting Security Issues

For security vulnerabilities in this gem, please email security@datocms.com instead of using the issue tracker.
