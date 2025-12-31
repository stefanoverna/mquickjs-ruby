#!/usr/bin/env ruby
# frozen_string_literal: true

# This test file comprehensively documents and tests the JavaScript API limitations
# in MQuickJS. It serves as both documentation and regression testing to ensure
# users know what works, what doesn't, and what has quirks.
#
# MQuickJS is based on MicroQuickJS, an extremely minimal JavaScript engine.
# It implements a strict ES5 subset with some ES6+ features like for...of (arrays only).

require "mquickjs"
require "minitest/autorun"

class TestJavaScriptAPILimitations < Minitest::Test
  def setup
    @sandbox = MQuickJS::Sandbox.new
  end

  # ============================================================================
  # SECTION 1: DATE - Severely Limited
  # ============================================================================
  # Only Date.now() is supported. No Date instances, no date parsing,
  # no date formatting, no timezone handling.

  def test_date_now_works
    result = @sandbox.eval("Date.now()")
    assert_kind_of Float, result.value
    assert_operator result.value, :>, 0
  end

  def test_date_constructor_fails
    error = assert_raises(MQuickJS::JavascriptError) do
      @sandbox.eval("new Date()")
    end
    assert_match(/only Date\.now\(\) is supported/, error.message)
  end

  def test_date_constructor_with_args_fails
    error = assert_raises(MQuickJS::JavascriptError) do
      @sandbox.eval("new Date(2024, 0, 15)")
    end
    assert_match(/only Date\.now\(\) is supported/, error.message)
  end

  def test_date_parse_fails
    error = assert_raises(MQuickJS::JavascriptError) do
      @sandbox.eval("new Date('2024-01-15')")
    end
    assert_match(/only Date\.now\(\) is supported/, error.message)
  end

  def test_date_instance_methods_unavailable
    # These would all require a Date instance, which we can't create
    %w[getTime getFullYear getMonth getDate getDay getHours getMinutes getSeconds
       getMilliseconds getTimezoneOffset toISOString toDateString toTimeString
       toString valueOf toJSON toLocaleDateString toLocaleTimeString].each do |method|
      error = assert_raises(MQuickJS::JavascriptError, "Expected new Date().#{method}() to fail") do
        @sandbox.eval("new Date().#{method}()")
      end
      assert_match(/only Date\.now\(\) is supported/, error.message)
    end
  end

  # ============================================================================
  # SECTION 2: ES6+ SYNTAX - Not Supported
  # ============================================================================
  # No let/const, no arrow functions, no template literals, no destructuring,
  # no spread operator, no classes, no async/await, no generators.

  def test_let_not_supported
    error = assert_raises(MQuickJS::SyntaxError) do
      @sandbox.eval("let x = 1")
    end
    assert_match(/SyntaxError/, error.message)
  end

  def test_const_not_supported
    error = assert_raises(MQuickJS::SyntaxError) do
      @sandbox.eval("const x = 1")
    end
    assert_match(/SyntaxError/, error.message)
  end

  def test_arrow_functions_not_supported
    error = assert_raises(MQuickJS::SyntaxError) do
      @sandbox.eval("[1,2,3].map(x => x * 2)")
    end
    assert_match(/SyntaxError/, error.message)
  end

  def test_template_literals_not_supported
    error = assert_raises(MQuickJS::SyntaxError) do
      @sandbox.eval('var x = "hello"; `value: ${x}`')
    end
    assert_match(/SyntaxError/, error.message)
  end

  def test_object_destructuring_not_supported
    error = assert_raises(MQuickJS::SyntaxError) do
      @sandbox.eval("var {a, b} = {a: 1, b: 2}")
    end
    assert_match(/SyntaxError/, error.message)
  end

  def test_array_destructuring_not_supported
    error = assert_raises(MQuickJS::SyntaxError) do
      @sandbox.eval("var [x, y] = [1, 2]")
    end
    assert_match(/SyntaxError/, error.message)
  end

  def test_spread_operator_not_supported
    error = assert_raises(MQuickJS::SyntaxError) do
      @sandbox.eval("var x = [...[1, 2, 3]]")
    end
    assert_match(/SyntaxError/, error.message)
  end

  def test_object_spread_not_supported
    error = assert_raises(MQuickJS::SyntaxError) do
      @sandbox.eval("var x = {...{a: 1}}")
    end
    assert_match(/SyntaxError/, error.message)
  end

  def test_classes_not_supported
    error = assert_raises(MQuickJS::SyntaxError) do
      @sandbox.eval("class Foo {}")
    end
    assert_match(/SyntaxError/, error.message)
  end

  def test_async_functions_not_supported
    error = assert_raises(MQuickJS::SyntaxError) do
      @sandbox.eval("async function foo() {}")
    end
    assert_match(/SyntaxError/, error.message)
  end

  def test_generators_not_supported
    error = assert_raises(MQuickJS::SyntaxError) do
      @sandbox.eval("function* gen() { yield 1; }")
    end
    assert_match(/SyntaxError/, error.message)
  end

  # ============================================================================
  # SECTION 3: FOR...OF - Works with Arrays Only
  # ============================================================================

  def test_for_of_with_arrays_works
    result = @sandbox.eval("var arr = [1,2,3]; var sum = 0; for (var x of arr) { sum += x; } sum")
    assert_equal 6, result.value
  end

  def test_for_of_with_string_not_supported
    # for...of only works with arrays, not strings
    error = assert_raises(MQuickJS::JavascriptError) do
      @sandbox.eval("var s = 'abc'; var chars = []; for (var c of s) { chars.push(c); } chars")
    end
    assert_match(/unsupported type in for\.\.\.of/, error.message)
  end

  # ============================================================================
  # SECTION 4: ARRAYS - Holes Not Allowed
  # ============================================================================
  # Arrays with holes (sparse arrays) are not supported. This is a significant
  # difference from standard JavaScript.

  def test_array_literal_with_hole_fails
    error = assert_raises(MQuickJS::SyntaxError) do
      @sandbox.eval("[1, , 3]")
    end
    assert_match(/SyntaxError/, error.message)
  end

  def test_new_array_initializes_with_undefined
    # Unlike standard JS, new Array(n) creates array with undefined values, not holes
    result = @sandbox.eval("var a = new Array(3); a")
    assert_equal [nil, nil, nil], result.value
  end

  def test_array_es5_methods_work
    working_methods = %w[map filter reduce forEach every some indexOf lastIndexOf
                         push pop shift unshift slice splice concat join reverse sort]
    working_methods.each do |method|
      result = @sandbox.eval("typeof [].#{method}")
      assert_equal "function", result.value, "Expected [].#{method} to be a function"
    end
  end

  def test_array_es6_methods_missing
    missing_methods = %w[find findIndex includes flat flatMap fill copyWithin entries keys values at]
    missing_methods.each do |method|
      result = @sandbox.eval("typeof [].#{method}")
      assert_equal "undefined", result.value, "Expected [].#{method} to be undefined"
    end
  end

  def test_array_static_methods_missing
    assert_equal "undefined", @sandbox.eval("typeof Array.from").value
    assert_equal "undefined", @sandbox.eval("typeof Array.of").value
  end

  def test_array_is_array_works
    assert @sandbox.eval("Array.isArray([])").value
    assert @sandbox.eval("Array.isArray([1,2,3])").value
    refute @sandbox.eval("Array.isArray({})").value
    refute @sandbox.eval("Array.isArray('string')").value
  end

  # ============================================================================
  # SECTION 5: STRING - Limited ES6+ Methods, ASCII-Only Case Folding
  # ============================================================================

  def test_string_es5_methods_work
    working_methods = %w[charAt charCodeAt slice substring concat indexOf lastIndexOf
                         match replace search split toLowerCase toUpperCase trim]
    working_methods.each do |method|
      result = @sandbox.eval("typeof ''.#{method}")
      assert_equal "function", result.value, "Expected ''.#{method} to be a function"
    end
  end

  def test_string_es6_methods_available
    # Some ES6 methods are actually available
    assert_equal "function", @sandbox.eval("typeof ''.codePointAt").value
    assert_equal "function", @sandbox.eval("typeof ''.replaceAll").value
    assert_equal "function", @sandbox.eval("typeof ''.trimStart").value
    assert_equal "function", @sandbox.eval("typeof ''.trimEnd").value
  end

  def test_string_es6_methods_missing
    missing_methods = %w[includes startsWith endsWith repeat padStart padEnd normalize at matchAll]
    missing_methods.each do |method|
      result = @sandbox.eval("typeof ''.#{method}")
      assert_equal "undefined", result.value, "Expected ''.#{method} to be undefined"
    end
  end

  def test_string_case_folding_ascii_only
    # ASCII letters work correctly
    assert_equal "HELLO", @sandbox.eval("'hello'.toUpperCase()").value
    assert_equal "world", @sandbox.eval("'WORLD'.toLowerCase()").value

    # Non-ASCII letters are NOT converted (this is a limitation!)
    # café should become CAFÉ, but é stays lowercase
    result = @sandbox.eval("'caf\\u00e9'.toUpperCase()")
    assert_equal "CAF\u00e9", result.value # Note: é is NOT uppercase

    # MÜNCHEN should become münchen, but Ü stays uppercase
    result = @sandbox.eval("'M\\u00dcNCHEN'.toLowerCase()")
    assert_equal "m\u00DCnchen", result.value # Note: Ü is NOT lowercase

    # Ñ should become ñ, but it doesn't
    result = @sandbox.eval("'\\u00d1'.toLowerCase()")
    assert_equal "\u00d1", result.value # Note: Ñ stays uppercase
  end

  def test_string_static_methods
    assert_equal "function", @sandbox.eval("typeof String.fromCharCode").value
    assert_equal "function", @sandbox.eval("typeof String.fromCodePoint").value
  end

  # ============================================================================
  # SECTION 6: OBJECT - Limited Methods
  # ============================================================================

  def test_object_available_methods
    available = %w[keys defineProperty create getPrototypeOf setPrototypeOf]
    available.each do |method|
      result = @sandbox.eval("typeof Object.#{method}")
      assert_equal "function", result.value, "Expected Object.#{method} to be a function"
    end
  end

  def test_object_missing_methods
    missing = %w[values entries assign freeze seal isFrozen isSealed isExtensible
                 preventExtensions fromEntries getOwnPropertyNames getOwnPropertyDescriptor]
    missing.each do |method|
      result = @sandbox.eval("typeof Object.#{method}")
      assert_equal "undefined", result.value, "Expected Object.#{method} to be undefined"
    end
  end

  def test_object_prototype_methods
    assert_equal "function", @sandbox.eval("typeof Object.prototype.hasOwnProperty").value
    assert_equal "function", @sandbox.eval("typeof Object.prototype.toString").value
  end

  # ============================================================================
  # SECTION 7: NUMBER - Limited Methods, Some Constants Available
  # ============================================================================

  def test_number_prototype_methods_work
    available = %w[toExponential toFixed toPrecision toString]
    available.each do |method|
      result = @sandbox.eval("typeof (1).#{method}")
      assert_equal "function", result.value, "Expected Number.prototype.#{method} to be a function"
    end
  end

  def test_number_static_methods_partial
    assert_equal "function", @sandbox.eval("typeof Number.parseFloat").value
    assert_equal "function", @sandbox.eval("typeof Number.parseInt").value
    assert_equal "undefined", @sandbox.eval("typeof Number.isInteger").value
    assert_equal "undefined", @sandbox.eval("typeof Number.isNaN").value
    assert_equal "undefined", @sandbox.eval("typeof Number.isFinite").value
    assert_equal "undefined", @sandbox.eval("typeof Number.isSafeInteger").value
  end

  def test_number_constants_available
    constants = %w[MAX_VALUE MIN_VALUE MAX_SAFE_INTEGER MIN_SAFE_INTEGER
                   POSITIVE_INFINITY NEGATIVE_INFINITY NaN EPSILON]
    constants.each do |const|
      result = @sandbox.eval("typeof Number.#{const}")
      assert_equal "number", result.value, "Expected Number.#{const} to be a number"
    end
  end

  # ============================================================================
  # SECTION 8: MATH - Core Functions Available, Some ES6+ Missing
  # ============================================================================

  def test_math_core_methods_work
    core = %w[min max abs floor ceil round sqrt sin cos tan asin acos atan atan2
              exp log pow random sign trunc log2 log10 imul clz32 fround]
    core.each do |method|
      result = @sandbox.eval("typeof Math.#{method}")
      assert_equal "function", result.value, "Expected Math.#{method} to be a function"
    end
  end

  def test_math_constants_available
    constants = %w[E LN10 LN2 LOG2E LOG10E PI SQRT1_2 SQRT2]
    constants.each do |const|
      result = @sandbox.eval("typeof Math.#{const}")
      assert_equal "number", result.value, "Expected Math.#{const} to be a number"
    end
  end

  def test_math_missing_methods
    missing = %w[cbrt expm1 log1p sinh cosh tanh asinh acosh atanh hypot]
    missing.each do |method|
      result = @sandbox.eval("typeof Math.#{method}")
      assert_equal "undefined", result.value, "Expected Math.#{method} to be undefined"
    end
  end

  # ============================================================================
  # SECTION 9: REGEXP - Basic Support Only
  # ============================================================================

  def test_regexp_basic_operations_work
    assert @sandbox.eval("/test/i.test('TEST')").value
    assert_equal ["test"], @sandbox.eval("/test/.exec('test string')").value
  end

  def test_regexp_source_and_flags_work
    assert_equal "test", @sandbox.eval("/test/gi.source").value
    assert_equal "gi", @sandbox.eval("/test/gi.flags").value
  end

  def test_regexp_flag_properties_missing
    # Flag accessor properties are not available
    missing = %w[global ignoreCase multiline dotAll unicode sticky]
    missing.each do |prop|
      result = @sandbox.eval("typeof /test/.#{prop}")
      assert_equal "undefined", result.value, "Expected /test/.#{prop} to be undefined"
    end
  end

  # ============================================================================
  # SECTION 10: JSON - Works but with Standard Quirks
  # ============================================================================

  def test_json_parse_works
    result = @sandbox.eval('JSON.parse(\'{"a": 1, "b": "hello"}\')').value
    assert_equal({ "a" => 1, "b" => "hello" }, result)
  end

  def test_json_stringify_works
    result = @sandbox.eval('JSON.stringify({a: 1, b: "hello"})').value
    assert_equal '{"a":1,"b":"hello"}', result
  end

  def test_json_stringify_functions_become_null
    # Functions are converted to null (if in object) or undefined (if standalone)
    result = @sandbox.eval("JSON.stringify({f: function(){}})").value
    assert_equal '{"f":null}', result
  end

  def test_json_stringify_undefined_omitted
    # Undefined properties are omitted
    result = @sandbox.eval("JSON.stringify({a: undefined, b: 1})").value
    assert_equal '{"b":1}', result
  end

  def test_json_stringify_circular_throws
    error = assert_raises(MQuickJS::JavascriptError) do
      @sandbox.eval("var o = {}; o.self = o; JSON.stringify(o)")
    end
    assert_match(/circular reference/, error.message)
  end

  # ============================================================================
  # SECTION 11: EVAL - Only Indirect Eval Supported
  # ============================================================================

  def test_indirect_eval_works
    result = @sandbox.eval("(1, eval)('1 + 2')")
    assert_equal 3, result.value
  end

  def test_direct_eval_not_supported
    error = assert_raises(MQuickJS::SyntaxError) do
      @sandbox.eval("(function() { var local = 42; return eval('local'); })()")
    end
    assert_match(/direct eval is not supported/, error.message)
  end

  # ============================================================================
  # SECTION 12: VALUE BOXING - Not Supported
  # ============================================================================
  # new Number(), new String(), new Boolean() are not supported

  def test_new_number_not_supported
    error = assert_raises(MQuickJS::JavascriptError) do
      @sandbox.eval("new Number(1)")
    end
    assert_match(/number constructor not supported/, error.message)
  end

  def test_new_string_not_supported
    error = assert_raises(MQuickJS::JavascriptError) do
      @sandbox.eval("new String('hello')")
    end
    assert_match(/string constructor not supported/, error.message)
  end

  def test_new_boolean_not_supported
    error = assert_raises(MQuickJS::JavascriptError) do
      @sandbox.eval("new Boolean(true)")
    end
    assert_match(/Boolean constructor not supported/, error.message)
  end

  # ============================================================================
  # SECTION 13: GLOBAL FUNCTIONS - Some Missing
  # ============================================================================

  def test_global_functions_available
    available = %w[parseInt parseFloat isNaN isFinite eval]
    available.each do |fn|
      result = @sandbox.eval("typeof #{fn}")
      assert_equal "function", result.value, "Expected #{fn} to be a function"
    end
  end

  def test_uri_functions_missing
    missing = %w[encodeURI decodeURI encodeURIComponent decodeURIComponent]
    missing.each do |fn|
      result = @sandbox.eval("typeof #{fn}")
      assert_equal "undefined", result.value, "Expected #{fn} to be undefined"
    end
  end

  def test_escape_unescape_missing
    assert_equal "undefined", @sandbox.eval("typeof escape").value
    assert_equal "undefined", @sandbox.eval("typeof unescape").value
  end

  def test_btoa_atob_missing
    assert_equal "undefined", @sandbox.eval("typeof btoa").value
    assert_equal "undefined", @sandbox.eval("typeof atob").value
  end

  # ============================================================================
  # SECTION 14: ES6+ BUILT-IN OBJECTS - Not Available
  # ============================================================================

  def test_symbol_not_available
    assert_equal "undefined", @sandbox.eval("typeof Symbol").value
  end

  def test_map_not_available
    assert_equal "undefined", @sandbox.eval("typeof Map").value
  end

  def test_set_not_available
    assert_equal "undefined", @sandbox.eval("typeof Set").value
  end

  def test_weakmap_not_available
    assert_equal "undefined", @sandbox.eval("typeof WeakMap").value
  end

  def test_weakset_not_available
    assert_equal "undefined", @sandbox.eval("typeof WeakSet").value
  end

  def test_promise_not_available
    assert_equal "undefined", @sandbox.eval("typeof Promise").value
  end

  def test_proxy_not_available
    assert_equal "undefined", @sandbox.eval("typeof Proxy").value
  end

  def test_reflect_not_available
    assert_equal "undefined", @sandbox.eval("typeof Reflect").value
  end

  # ============================================================================
  # SECTION 15: STRICT MODE BEHAVIOR
  # ============================================================================
  # MQuickJS enforces strict mode. Undeclared variables throw errors,
  # 'with' statement is not allowed.

  def test_undeclared_variable_throws
    error = assert_raises(MQuickJS::JavascriptError) do
      @sandbox.eval("undeclaredVar = 42")
    end
    assert_match(/ReferenceError.*undeclaredVar.*not defined/, error.message)
  end

  def test_with_statement_not_supported
    error = assert_raises(MQuickJS::SyntaxError) do
      @sandbox.eval("with({x:1}) { x }")
    end
    assert_match(/SyntaxError/, error.message)
  end

  # ============================================================================
  # SECTION 16: TYPED ARRAYS - Available
  # ============================================================================

  def test_typed_arrays_available
    typed_arrays = %w[ArrayBuffer Uint8Array Uint8ClampedArray Int8Array
                      Uint16Array Int16Array Uint32Array Int32Array
                      Float32Array Float64Array]
    typed_arrays.each do |ta|
      result = @sandbox.eval("typeof #{ta}")
      assert_equal "function", result.value, "Expected #{ta} to be a function"
    end
  end

  def test_typed_array_basic_operations
    result = @sandbox.eval("var arr = new Uint8Array(3); arr[0] = 1; arr[1] = 2; arr[2] = 3; arr.join(',')")
    assert_equal "1,2,3", result.value
  end

  # ============================================================================
  # SECTION 17: ERROR TYPES - Available
  # ============================================================================

  def test_error_types_available
    error_types = %w[Error TypeError ReferenceError RangeError SyntaxError URIError EvalError]
    error_types.each do |et|
      result = @sandbox.eval("typeof #{et}")
      assert_equal "function", result.value, "Expected #{et} to be a function"
    end
  end

  def test_error_message_and_stack
    error = assert_raises(MQuickJS::JavascriptError) do
      @sandbox.eval("throw new Error('test message')")
    end
    assert_match(/test message/, error.message)
    assert_kind_of String, error.stack
  end

  # ============================================================================
  # SECTION 18: FUNCTION METHODS - Available
  # ============================================================================

  def test_function_methods_available
    methods = %w[call apply bind]
    methods.each do |method|
      result = @sandbox.eval("typeof Function.prototype.#{method}")
      assert_equal "function", result.value, "Expected Function.prototype.#{method} to be a function"
    end
  end

  def test_function_length_and_name
    result = @sandbox.eval("(function foo(a, b) {}).length")
    assert_equal 2, result.value

    result = @sandbox.eval("(function foo(a, b) {}).name")
    assert_equal "foo", result.value
  end

  # ============================================================================
  # SECTION 19: SPECIAL GLOBAL VALUES
  # ============================================================================

  def test_infinity_available
    assert @sandbox.eval("Infinity > 0").value
    assert @sandbox.eval("-Infinity < 0").value
    assert_equal Float::INFINITY, @sandbox.eval("Infinity").value
    assert_equal(-Float::INFINITY, @sandbox.eval("-Infinity").value)
  end

  def test_nan_available
    assert @sandbox.eval("isNaN(NaN)").value
    assert @sandbox.eval("NaN !== NaN").value
  end

  def test_undefined_and_null
    assert_nil @sandbox.eval("undefined").value
    assert_nil @sandbox.eval("null").value
    assert_equal "undefined", @sandbox.eval("typeof undefined").value
    assert_equal "object", @sandbox.eval("typeof null").value
  end

  def test_global_this_available
    result = @sandbox.eval("typeof globalThis")
    assert_equal "object", result.value
  end

  # ============================================================================
  # SECTION 20: WORKAROUNDS FOR COMMON PATTERNS
  # ============================================================================
  # These tests document recommended workarounds for missing features

  def test_workaround_for_includes
    # Instead of array.includes(item), use indexOf
    result = @sandbox.eval("[1, 2, 3].indexOf(2) !== -1")
    assert result.value
  end

  def test_workaround_for_find
    # Instead of array.find(fn), use filter()[0]
    result = @sandbox.eval("[1, 2, 3, 4].filter(function(x) { return x > 2; })[0]")
    assert_equal 3, result.value
  end

  def test_workaround_for_string_includes
    # Instead of str.includes(substr), use indexOf
    result = @sandbox.eval("'hello world'.indexOf('world') !== -1")
    assert result.value
  end

  def test_workaround_for_starts_with
    # Instead of str.startsWith(prefix), use indexOf === 0
    result = @sandbox.eval("'hello world'.indexOf('hello') === 0")
    assert result.value
  end

  def test_workaround_for_ends_with
    # Instead of str.endsWith(suffix), use slice
    result = @sandbox.eval("'hello world'.slice(-5) === 'world'")
    assert result.value
  end

  def test_workaround_for_object_assign
    # Instead of Object.assign, manually copy properties
    code = <<~JS
      var target = {a: 1};
      var source = {b: 2, c: 3};
      Object.keys(source).forEach(function(key) {
        target[key] = source[key];
      });
      JSON.stringify(target);
    JS
    result = @sandbox.eval(code)
    assert_equal '{"a":1,"b":2,"c":3}', result.value
  end

  def test_workaround_for_object_values
    # Instead of Object.values, use Object.keys with map
    code = <<~JS
      var obj = {a: 1, b: 2, c: 3};
      Object.keys(obj).map(function(key) { return obj[key]; });
    JS
    result = @sandbox.eval(code)
    assert_equal [1, 2, 3], result.value
  end

  def test_workaround_for_object_entries
    # Instead of Object.entries, use Object.keys with map
    code = <<~JS
      var obj = {a: 1, b: 2};
      Object.keys(obj).map(function(key) { return [key, obj[key]]; });
    JS
    result = @sandbox.eval(code)
    assert_equal [%w[a 1], %w[b 2]], result.value.map { |k, v| [k, v.to_s] }
  end

  def test_workaround_for_spread_array
    # Instead of [...arr1, ...arr2], use concat
    result = @sandbox.eval("[1, 2].concat([3, 4])")
    assert_equal [1, 2, 3, 4], result.value
  end

  def test_workaround_for_template_literals
    # Instead of `Hello ${name}`, use string concatenation
    result = @sandbox.eval("var name = 'World'; 'Hello ' + name + '!'")
    assert_equal "Hello World!", result.value
  end

  def test_workaround_for_arrow_functions
    # Instead of (x) => x * 2, use function(x) { return x * 2; }
    result = @sandbox.eval("[1, 2, 3].map(function(x) { return x * 2; })")
    assert_equal [2, 4, 6], result.value
  end

  def test_workaround_for_destructuring
    # Instead of var {a, b} = obj, access properties individually
    code = <<~JS
      var obj = {a: 1, b: 2, c: 3};
      var a = obj.a;
      var b = obj.b;
      a + b;
    JS
    result = @sandbox.eval(code)
    assert_equal 3, result.value
  end

  def test_workaround_for_classes
    # Instead of class, use constructor functions with prototypes
    code = <<~JS
      function Person(name, age) {
        this.name = name;
        this.age = age;
      }
      Person.prototype.greet = function() {
        return 'Hello, ' + this.name;
      };
      var p = new Person('Alice', 30);
      p.greet();
    JS
    result = @sandbox.eval(code)
    assert_equal "Hello, Alice", result.value
  end

  def test_workaround_for_default_parameters
    # Instead of function(x = 1), check for undefined
    code = <<~JS
      function greet(name) {
        if (typeof name === 'undefined') name = 'World';
        return 'Hello ' + name;
      }
      greet();
    JS
    result = @sandbox.eval(code)
    assert_equal "Hello World", result.value
  end

  def test_workaround_for_rest_parameters
    # Instead of function(...args), use arguments
    code = <<~JS
      function sum() {
        var total = 0;
        for (var i = 0; i < arguments.length; i++) {
          total += arguments[i];
        }
        return total;
      }
      sum(1, 2, 3, 4, 5);
    JS
    result = @sandbox.eval(code)
    assert_equal 15, result.value
  end
end
