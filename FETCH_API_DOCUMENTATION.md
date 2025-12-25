# Fetch API Implementation for MQuickJS Ruby Sandbox

## Overview

This implementation adds `fetch()` API support to the MQuickJS Ruby sandbox by modifying the mquickjs stdlib and adding native C functions. The implementation follows a hybrid approach that allows JavaScript code to make HTTP requests through a Ruby callback mechanism.

## Implementation Approach

**Method:** Modified mquickjs stdlib (Option A)

### What Was Modified

1. **mqjs_stdlib.h** - Added fetch to the standard library:
   - Added "fetch" atom to the atom table (offset 552)
   - Added "fetch" to the sorted atom table
   - Added `js_fetch` to the C function table
   - Updated stdlib metadata (function count from 64 to 65, last atom offset from 552 to 555)

2. **mquickjs_ext.c** - Implemented the C function and Ruby integration:
   - Added `js_fetch()` C function that mimics the Web Fetch API
   - Added `sandbox_set_http_callback()` to set the Ruby HTTP executor
   - Added `http_callback` field to the ContextWrapper struct

## JavaScript API

### fetch(url[, options])

Makes an HTTP request and returns a Response object synchronously.

**Parameters:**
- `url` (string): The URL to fetch
- `options` (object, optional): Request options
  - `method` (string): HTTP method (default: "GET")
  - `body` (string): Request body for POST/PUT requests

**Returns:** Response object with the following properties:
- `status` (number): HTTP status code
- `statusText` (string): HTTP status text
- `ok` (boolean): True if status is 200-299
- `body` (string): Response body
- `headers` (object): Response headers

**Example:**
```javascript
// Simple GET request
var response = fetch('https://api.example.com/data');
var data = JSON.parse(response.body);
console.log(data.message);

// POST request with body
var response = fetch('https://api.example.com/users', {
  method: 'POST',
  body: JSON.stringify({name: 'John', age: 30})
});
console.log(response.status); // 200
```

## Ruby Integration

### Setting Up the HTTP Callback

The sandbox requires an HTTP callback to execute actual HTTP requests:

```ruby
sandbox = MQuickJS::NativeSandbox.new

# Define the HTTP callback
http_callback = lambda do |method, url, body, headers|
  # Execute the HTTP request (use Net::HTTP, HTTParty, etc.)
  response = make_http_request(method, url, body, headers)

  # Return a hash with the response
  {
    status: response.code.to_i,
    statusText: response.message,
    body: response.body,
    headers: response.to_hash
  }
end

# Set the callback
sandbox.http_callback = http_callback

# Now JavaScript can use fetch()
result = sandbox.eval("fetch('https://api.example.com/data').body")
```

## Differences from Web Fetch API

This implementation differs from the standard Web Fetch API in the following ways:

1. **Synchronous, not Promise-based**: Returns a Response object directly instead of a Promise
2. **No streaming**: The entire response body is loaded at once
3. **Limited Response methods**: No `.text()` or `.json()` methods - use `response.body` and `JSON.parse()` instead
4. **No Request object**: Options are passed directly as a plain object
5. **No Headers API**: Headers are returned as a plain object
6. **No abort support**: Cannot cancel in-flight requests

## Security Considerations

- HTTP execution happens through Ruby callback, allowing full control over:
  - URL whitelist/blacklist
  - Rate limiting
  - Timeout enforcement
  - IP restrictions
  - TLS/SSL validation

Example with HTTPExecutor:
```ruby
require_relative 'lib/mquickjs/http_executor'

http_config = MQuickJS::HTTPConfig.new(
  whitelist: ['https://api.github.com/**'],
  rate_limit: 10,
  timeout: 5000
)

executor = MQuickJS::HTTPExecutor.new(http_config)

sandbox.http_callback = lambda do |method, url, body, headers|
  executor.execute(method, url, body: body, headers: headers)
end
```

## Error Handling

Errors are thrown as JavaScript errors:

```javascript
// If HTTP callback is not set
var response = fetch('https://example.com');
// Throws: "fetch() is not enabled - HTTP callback not configured"

// If URL is missing
var response = fetch();
// Throws: "fetch() requires at least 1 argument (url)"

// If Ruby callback raises an exception
var response = fetch('https://blocked-site.com');
// Throws: "HTTP request failed"
```

## Performance Notes

- Synchronous execution may block the JavaScript VM
- Each fetch() call crosses the C/Ruby boundary twice
- Response bodies are copied between Ruby and JavaScript memory
- Best suited for small to medium-sized responses

## Future Enhancements

Potential improvements for future versions:

1. Add `.text()` and `.json()` methods to Response objects
2. Support for Request objects with full configuration
3. Implement Headers API for better header manipulation
4. Add streaming support for large responses
5. Promise-based async API (requires Promise support in mquickjs)
6. Support for FormData and file uploads
7. Better error messages and error types
8. Response caching

## Testing

See `test_fetch.rb` for usage examples and test cases.

## Credits

Implementation by Claude Code as part of the MQuickJS Ruby Sandbox project.
Based on the Web Fetch API specification (https://fetch.spec.whatwg.org/)
