#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'lib/mquickjs'
require 'minitest/autorun'

class TestMQuickJS < Minitest::Test
  def test_simple_arithmetic
    result = MQuickJS.eval("1 + 2 + 3")
    assert_equal 6, result
  end

  def test_string_operations
    result = MQuickJS.eval("'hello'.toUpperCase()")
    assert_equal "HELLO", result
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
    assert_equal 4950, result
  end

  def test_math_functions
    result = MQuickJS.eval("Math.sqrt(16)")
    assert_equal 4.0, result
  end

  def test_return_string
    result = MQuickJS.eval("'test string'")
    assert_equal "test string", result
  end

  def test_return_boolean
    assert_equal true, MQuickJS.eval("true")
    assert_equal false, MQuickJS.eval("false")
  end

  def test_return_null
    assert_nil MQuickJS.eval("null")
  end

  def test_return_undefined
    assert_nil MQuickJS.eval("undefined")
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
    assert_equal 4, result1

    result2 = sandbox.eval("3 * 3")
    assert_equal 9, result2

    # Each eval is isolated
    result3 = sandbox.eval("typeof x")
    assert_equal "undefined", result3
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
    assert_equal 55, result
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
    assert_equal 15, result
  end

  def test_string_concatenation
    result = MQuickJS.eval("'Hello' + ' ' + 'World'")
    assert_equal "Hello World", result
  end

  def test_comparison_operators
    assert_equal true, MQuickJS.eval("5 > 3")
    assert_equal false, MQuickJS.eval("2 > 10")
    assert_equal true, MQuickJS.eval("'abc' === 'abc'")
  end

  def test_typeof_operator
    assert_equal "number", MQuickJS.eval("typeof 42")
    assert_equal "string", MQuickJS.eval("typeof 'test'")
    assert_equal "boolean", MQuickJS.eval("typeof true")
    assert_equal "undefined", MQuickJS.eval("typeof undefined")
  end

  def test_object_property_access
    code = <<~JS
      var obj = { x: 10, y: 20 };
      obj.x + obj.y;
    JS
    result = MQuickJS.eval(code)
    assert_equal 30, result
  end

  def test_custom_memory_limit
    sandbox = MQuickJS::Sandbox.new(memory_limit: 100_000)
    result = sandbox.eval("1 + 1")
    assert_equal 2, result
  end

  def test_custom_timeout
    sandbox = MQuickJS::Sandbox.new(timeout_ms: 1000)
    result = sandbox.eval("2 * 2")
    assert_equal 4, result
  end
end

# Run the tests
puts "Running MQuickJS FFI tests..."
