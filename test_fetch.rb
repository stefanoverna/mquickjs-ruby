#!/usr/bin/env ruby
# Test script for fetch() implementation

require_relative 'mquickjs-ruby-native/lib/mquickjs'

# Create a sandbox
sandbox = MQuickJS::Sandbox.new

# Set up the HTTP callback
# This callback will be called from C when fetch() is invoked from JavaScript
http_callback = lambda do |method, url, body, headers|
  puts "HTTP Callback invoked:"
  puts "  Method: #{method}"
  puts "  URL: #{url}"
  puts "  Body: #{body.inspect}"
  puts "  Headers: #{headers.inspect}"

  # Return a mock response
  {
    status: 200,
    statusText: "OK",
    body: '{"message": "Hello from fetch()!", "timestamp": 1234567890}',
    headers: { "content-type" => "application/json" }
  }
end

sandbox.http_callback = http_callback

# Test basic fetch() call
puts "=== Test 1: Basic fetch() call ==="
result = sandbox.eval(<<~JS)
  var response = fetch('https://api.example.com/data');
  response.body;
JS

puts "JavaScript returned: #{result.value}"
puts "Console output: #{result.console_output}"
puts

# Test fetch() with options
puts "=== Test 2: fetch() with POST method ==="
result = sandbox.eval(<<~JS)
  var response = fetch('https://api.example.com/users', {
    method: 'POST',
    body: JSON.stringify({name: 'John', age: 30})
  });
  response.status;
JS

puts "JavaScript returned: #{result.value}"
puts "Console output: #{result.console_output}"
puts

# Test fetch() response properties
puts "=== Test 3: Check response properties ==="
result = sandbox.eval(<<~JS)
  var response = fetch('https://api.example.com/data');
  var results = {
    status: response.status,
    statusText: response.statusText,
    ok: response.ok,
    hasBody: typeof response.body === 'string'
  };
  JSON.stringify(results);
JS

puts "JavaScript returned: #{result.value}"
puts

# Test parsing JSON from response
puts "=== Test 4: Parse JSON from response ==="
result = sandbox.eval(<<~JS)
  var response = fetch('https://api.example.com/data');
  var data = JSON.parse(response.body);
  data.message;
JS

puts "JavaScript returned: #{result.value}"
puts

puts "All tests completed!"
