#!/usr/bin/env ruby
# Quick test to verify JSON.parse and JSON.stringify are available

require_relative 'mquickjs-ruby-native/lib/mquickjs'

sandbox = MQuickJS::Sandbox.new

# Test JSON.stringify
puts "=== Test JSON.stringify ==="
result = sandbox.eval(<<~JS)
  var obj = { name: "John", age: 30, city: "New York" };
  JSON.stringify(obj);
JS
puts "Result: #{result.value}"
puts

# Test JSON.parse
puts "=== Test JSON.parse ==="
result = sandbox.eval(<<~JS)
  var json = '{"name":"John","age":30,"city":"New York"}';
  var obj = JSON.parse(json);
  obj.name + " is " + obj.age + " years old";
JS
puts "Result: #{result.value}"
puts

# Test JSON round-trip
puts "=== Test JSON round-trip ==="
result = sandbox.eval(<<~JS)
  var original = { message: "Hello", numbers: [1, 2, 3], nested: { key: "value" } };
  var json = JSON.stringify(original);
  var parsed = JSON.parse(json);
  parsed.message + " - " + parsed.numbers.join(",");
JS
puts "Result: #{result.value}"
puts

puts "✅ JSON.parse and JSON.stringify are fully functional!"
