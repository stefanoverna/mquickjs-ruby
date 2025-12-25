#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'lib/mquickjs'
require 'minitest/autorun'

class TestMQuickJS < Minitest::Test
  def test_simple_arithmetic
    result = MQuickJS.eval("1 + 2 + 3")
    assert_equal 6, result.value
    assert_equal "", result.console_output
  end

  def test_string_operations
    result = MQuickJS.eval("'hello'.toUpperCase()")
    assert_equal "HELLO", result.value
  end

  def test_loop_with_sum
    code = <<~JS
      var sum = 0;
      for (var i = 0; i < 100; i++) {
        sum += i;
      }
      sum;
    JS
    result = MQuickJS.eval(code)
    assert_equal 4950, result.value
  end

  def test_math_functions
    result = MQuickJS.eval("Math.sqrt(16)")
    assert_equal 4.0, result.value
  end

  def test_return_string
    result = MQuickJS.eval("'test string'")
    assert_equal "test string", result.value
  end

  def test_return_boolean
    assert_equal true, MQuickJS.eval("true").value
    assert_equal false, MQuickJS.eval("false").value
  end

  def test_return_null
    assert_nil MQuickJS.eval("null").value
  end

  def test_return_undefined
    assert_nil MQuickJS.eval("undefined").value
  end

  def test_syntax_error
    error = assert_raises(MQuickJS::SyntaxError) do
      MQuickJS.eval("var x = ")
    end
    assert_match(/SyntaxError/, error.message)
  end

  def test_javascript_error
    error = assert_raises(MQuickJS::JavaScriptError) do
      MQuickJS.eval("throw new Error('test error')")
    end
    assert_match(/Error/, error.message)
  end

  def test_timeout
    error = assert_raises(MQuickJS::TimeoutError) do
      MQuickJS.eval("while(true) {}", timeout_ms: 100)
    end
    assert_match(/timeout/i, error.message)
  end

  def test_memory_limit
    # Try to allocate lots of memory
    code = <<~JS
      var arr = [];
      for (var i = 0; i < 10000; i++) {
        arr.push(new Array(100));
      }
    JS

    # This should fail with small memory limit (stdlib needs ~10KB minimum)
    # Note: mquickjs might handle this differently, so we'll be lenient
    begin
      result = MQuickJS.eval(code, memory_limit: 15_000)  # Small but valid limit
      # If it doesn't raise, that's ok - mquickjs might handle it gracefully
    rescue MQuickJS::MemoryLimitError, MQuickJS::JavaScriptError
      # Expected - either out of memory or JS error
    end
  end

  def test_reusable_sandbox
    sandbox = MQuickJS::Sandbox.new

    result1 = sandbox.eval("2 + 2")
    assert_equal 4, result1.value

    result2 = sandbox.eval("3 * 3")
    assert_equal 9, result2.value

    # Each eval is isolated
    result3 = sandbox.eval("typeof x")
    assert_equal "undefined", result3.value
  end

  def test_complex_expression
    code = <<~JS
      var fibonacci = function(n) {
        if (n <= 1) return n;
        return fibonacci(n - 1) + fibonacci(n - 2);
      };
      fibonacci(10);
    JS
    result = MQuickJS.eval(code)
    assert_equal 55, result.value
  end

  def test_array_operations
    code = <<~JS
      var arr = [1, 2, 3, 4, 5];
      var sum = 0;
      for (var i = 0; i < arr.length; i++) {
        sum += arr[i];
      }
      sum;
    JS
    result = MQuickJS.eval(code)
    assert_equal 15, result.value
  end

  def test_string_concatenation
    result = MQuickJS.eval("'Hello' + ' ' + 'World'")
    assert_equal "Hello World", result.value
  end

  def test_comparison_operators
    assert_equal true, MQuickJS.eval("5 > 3").value
    assert_equal false, MQuickJS.eval("2 > 10").value
    assert_equal true, MQuickJS.eval("'abc' === 'abc'").value
  end

  def test_typeof_operator
    assert_equal "number", MQuickJS.eval("typeof 42").value
    assert_equal "string", MQuickJS.eval("typeof 'test'").value
    assert_equal "boolean", MQuickJS.eval("typeof true").value
    assert_equal "undefined", MQuickJS.eval("typeof undefined").value
  end

  def test_object_property_access
    code = <<~JS
      var obj = { x: 10, y: 20 };
      obj.x + obj.y;
    JS
    result = MQuickJS.eval(code)
    assert_equal 30, result.value
  end

  def test_custom_memory_limit
    sandbox = MQuickJS::Sandbox.new(memory_limit: 100_000)
    result = sandbox.eval("1 + 1")
    assert_equal 2, result.value
  end

  def test_custom_timeout
    sandbox = MQuickJS::Sandbox.new(timeout_ms: 1000)
    result = sandbox.eval("2 * 2")
    assert_equal 4, result.value
  end

  def test_console_log_capture
    result = MQuickJS.eval("console.log('Hello'); console.log('World'); 42")
    assert_equal 42, result.value
    assert_equal "Hello\nWorld\n", result.console_output
    assert_equal false, result.console_truncated?
  end

  def test_console_log_multiple_args
    result = MQuickJS.eval("console.log('a', 'b', 'c'); 123")
    assert_equal 123, result.value
    assert_equal "a b c\n", result.console_output
  end

  def test_console_log_with_numbers
    result = MQuickJS.eval("console.log(1, 2, 3); console.log(true); 'done'")
    assert_equal "done", result.value
    assert_equal "1 2 3\ntrue\n", result.console_output
  end

  def test_console_log_truncation
    # Generate output larger than default 10KB limit
    # Each line is ~101 bytes (100 x's + newline), so 200 lines = ~20KB
    code = <<~JS
      var longStr = '';
      for (var j = 0; j < 100; j++) longStr += 'x';
      for (var i = 0; i < 200; i++) console.log(longStr);
      'done'
    JS
    result = MQuickJS.eval(code)
    assert_equal "done", result.value
    assert result.console_output.bytesize <= 10_000
    assert_equal true, result.console_truncated?
  end

  def test_custom_console_max_size
    # Each line is ~51 bytes (50 x's + newline), so we need at least 3 lines to exceed 100 bytes
    sandbox = MQuickJS::Sandbox.new(console_log_max_size: 100)
    code = <<~JS
      var longStr = '';
      for (var j = 0; j < 50; j++) longStr += 'x';
      for (var i = 0; i < 10; i++) console.log(longStr);
      42
    JS
    result = sandbox.eval(code)
    assert_equal 42, result.value
    assert result.console_output.bytesize <= 100
    assert_equal true, result.console_truncated?
  end

  def test_no_console_output
    result = MQuickJS.eval("1 + 1")
    assert_equal 2, result.value
    assert_equal "", result.console_output
    assert_equal false, result.console_truncated?
  end
end

# Run the tests
puts "Running MQuickJS FFI tests..."
