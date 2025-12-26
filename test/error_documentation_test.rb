# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/mquickjs"

# Tests to verify README error documentation is accurate
class ErrorDocumentationTest < Minitest::Test
  def setup
    @sandbox = MQuickJS::Sandbox.new
  end

  # ==========================================================================
  # SyntaxError Tests
  # ==========================================================================

  def test_syntax_error_incomplete_statement
    error = assert_raises(MQuickJS::SyntaxError) do
      @sandbox.eval("var x = ")
    end
    assert_equal "SyntaxError: unexpected character in expression", error.message
  end

  def test_syntax_error_const_keyword
    error = assert_raises(MQuickJS::SyntaxError) do
      @sandbox.eval("const x = 10")
    end
    assert_equal "SyntaxError: unexpected character in expression", error.message
  end

  def test_syntax_error_let_keyword
    error = assert_raises(MQuickJS::SyntaxError) do
      @sandbox.eval("let y = 20")
    end
    assert_equal "SyntaxError: unexpected character in expression", error.message
  end

  def test_syntax_error_arrow_function
    error = assert_raises(MQuickJS::SyntaxError) do
      @sandbox.eval("[1,2,3].map(x => x * 2)")
    end
    assert_equal "SyntaxError: unexpected character in expression", error.message
  end

  def test_syntax_error_template_literal
    error = assert_raises(MQuickJS::SyntaxError) do
      @sandbox.eval("`template ${literal}`")
    end
    assert_equal "SyntaxError: unexpected character in expression", error.message
  end

  def test_syntax_error_anonymous_function_declaration
    error = assert_raises(MQuickJS::SyntaxError) do
      @sandbox.eval("function() {}")
    end
    assert_equal "SyntaxError: function name expected", error.message
  end

  # ==========================================================================
  # JavaScriptError Tests
  # ==========================================================================

  def test_javascript_error_undefined_variable
    error = assert_raises(MQuickJS::JavaScriptError) do
      @sandbox.eval("undefinedVariable")
    end
    assert_equal "ReferenceError: variable 'undefinedVariable' is not defined", error.message
  end

  def test_javascript_error_null_property_access
    error = assert_raises(MQuickJS::JavaScriptError) do
      @sandbox.eval("null.foo")
    end
    assert_equal "TypeError: cannot read property 'foo' of null", error.message
  end

  def test_javascript_error_calling_non_function
    error = assert_raises(MQuickJS::JavaScriptError) do
      @sandbox.eval("var x = {}; x.foo()")
    end
    assert_equal "TypeError: not a function", error.message
  end

  def test_javascript_error_explicit_throw
    error = assert_raises(MQuickJS::JavaScriptError) do
      @sandbox.eval("throw new Error('something went wrong')")
    end
    assert_equal "Error: something went wrong", error.message
  end

  def test_javascript_error_null_name_property
    error = assert_raises(MQuickJS::JavaScriptError) do
      @sandbox.eval(<<~JS)
        function processUser(user) {
          return user.name.toUpperCase();
        }
        processUser(null);
      JS
    end
    assert_equal "TypeError: cannot read property 'name' of null", error.message
  end

  def test_javascript_error_custom_type_error
    error = assert_raises(MQuickJS::JavaScriptError) do
      @sandbox.eval(<<~JS)
        function validateAge(age) {
          if (typeof age !== 'number') {
            throw new TypeError('age must be a number, got ' + typeof age);
          }
          return age;
        }
        validateAge("twenty");
      JS
    end
    assert_equal "TypeError: age must be a number, got string", error.message
  end

  def test_javascript_error_custom_range_error
    error = assert_raises(MQuickJS::JavaScriptError) do
      @sandbox.eval("throw new RangeError('value out of range')")
    end
    assert_equal "RangeError: value out of range", error.message
  end

  # ==========================================================================
  # Error Type Parsing
  # ==========================================================================

  def test_error_type_can_be_parsed_from_message
    error = assert_raises(MQuickJS::JavaScriptError) do
      @sandbox.eval("undefinedVariable")
    end
    error_type = error.message.split(':').first
    assert_equal "ReferenceError", error_type
  end
end
