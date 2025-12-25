require 'minitest/autorun'
require_relative '../lib/mquickjs'

class FetchTest < Minitest::Test
  def setup
    @sandbox = MQuickJS::Sandbox.new
    @http_responses = []
    @http_requests = []

    # Default HTTP callback that tracks requests
    @sandbox.http_callback = lambda do |method, url, body, headers|
      request = { method: method, url: url, body: body, headers: headers }
      @http_requests << request

      # Return a default response (can be overridden per test)
      @http_responses.shift || default_response
    end
  end

  def default_response
    {
      status: 200,
      statusText: "OK",
      body: '{"message": "success"}',
      headers: { "content-type" => "application/json" }
    }
  end

  def queue_response(response)
    @http_responses << response
  end

  # ============================================================================
  # Basic Request Tests
  # ============================================================================

  def test_basic_get_request
    result = @sandbox.eval("fetch('https://api.example.com/data').body")

    assert_equal '{"message": "success"}', result.value
    assert_equal 1, @http_requests.length
    assert_equal 'GET', @http_requests[0][:method]
    assert_equal 'https://api.example.com/data', @http_requests[0][:url]
  end

  def test_post_request
    result = @sandbox.eval(<<~JS)
      fetch('https://api.example.com/users', { method: 'POST' }).status
    JS

    assert_equal 200, result.value
    assert_equal 'POST', @http_requests[0][:method]
  end

  def test_put_request
    result = @sandbox.eval(<<~JS)
      fetch('https://api.example.com/users/1', { method: 'PUT' }).status
    JS

    assert_equal 200, result.value
    assert_equal 'PUT', @http_requests[0][:method]
  end

  def test_delete_request
    result = @sandbox.eval(<<~JS)
      fetch('https://api.example.com/users/1', { method: 'DELETE' }).status
    JS

    assert_equal 200, result.value
    assert_equal 'DELETE', @http_requests[0][:method]
  end

  def test_patch_request
    result = @sandbox.eval(<<~JS)
      fetch('https://api.example.com/users/1', { method: 'PATCH' }).status
    JS

    assert_equal 200, result.value
    assert_equal 'PATCH', @http_requests[0][:method]
  end

  def test_head_request
    result = @sandbox.eval(<<~JS)
      fetch('https://api.example.com/data', { method: 'HEAD' }).status
    JS

    assert_equal 200, result.value
    assert_equal 'HEAD', @http_requests[0][:method]
  end

  def test_options_request
    result = @sandbox.eval(<<~JS)
      fetch('https://api.example.com/data', { method: 'OPTIONS' }).status
    JS

    assert_equal 200, result.value
    assert_equal 'OPTIONS', @http_requests[0][:method]
  end

  # ============================================================================
  # Request Body Tests
  # ============================================================================

  def test_request_with_string_body
    result = @sandbox.eval(<<~JS)
      fetch('https://api.example.com/users', {
        method: 'POST',
        body: 'plain text body'
      }).status
    JS

    assert_equal 200, result.value
    assert_equal 'plain text body', @http_requests[0][:body]
  end

  def test_request_with_json_body
    result = @sandbox.eval(<<~JS)
      fetch('https://api.example.com/users', {
        method: 'POST',
        body: JSON.stringify({name: 'John', age: 30})
      }).status
    JS

    assert_equal 200, result.value
    assert_equal '{"name":"John","age":30}', @http_requests[0][:body]
  end

  def test_request_with_empty_body
    result = @sandbox.eval(<<~JS)
      fetch('https://api.example.com/users', {
        method: 'POST',
        body: ''
      }).status
    JS

    assert_equal 200, result.value
    assert_equal '', @http_requests[0][:body]
  end

  def test_request_without_body
    result = @sandbox.eval(<<~JS)
      fetch('https://api.example.com/data').status
    JS

    assert_equal 200, result.value
    assert_nil @http_requests[0][:body]
  end

  def test_request_with_special_characters_in_body
    result = @sandbox.eval(<<~JS)
      fetch('https://api.example.com/data', {
        method: 'POST',
        body: 'Hello "World" \\n\\t<>&'
      }).status
    JS

    assert_equal 200, result.value
    assert_includes @http_requests[0][:body], 'Hello'
  end

  # ============================================================================
  # Response Property Tests
  # ============================================================================

  def test_response_status
    queue_response(status: 201, statusText: "Created", body: "", headers: {})

    result = @sandbox.eval("fetch('https://api.example.com/users').status")
    assert_equal 201, result.value
  end

  def test_response_status_text
    queue_response(status: 404, statusText: "Not Found", body: "", headers: {})

    result = @sandbox.eval("fetch('https://api.example.com/users').statusText")
    assert_equal "Not Found", result.value
  end

  def test_response_ok_true_for_200
    queue_response(status: 200, statusText: "OK", body: "", headers: {})

    result = @sandbox.eval("fetch('https://api.example.com/data').ok")
    assert_equal true, result.value
  end

  def test_response_ok_true_for_299
    queue_response(status: 299, statusText: "OK", body: "", headers: {})

    result = @sandbox.eval("fetch('https://api.example.com/data').ok")
    assert_equal true, result.value
  end

  def test_response_ok_false_for_199
    queue_response(status: 199, statusText: "Info", body: "", headers: {})

    result = @sandbox.eval("fetch('https://api.example.com/data').ok")
    assert_equal false, result.value
  end

  def test_response_ok_false_for_300
    queue_response(status: 300, statusText: "Redirect", body: "", headers: {})

    result = @sandbox.eval("fetch('https://api.example.com/data').ok")
    assert_equal false, result.value
  end

  def test_response_ok_false_for_404
    queue_response(status: 404, statusText: "Not Found", body: "", headers: {})

    result = @sandbox.eval("fetch('https://api.example.com/data').ok")
    assert_equal false, result.value
  end

  def test_response_ok_false_for_500
    queue_response(status: 500, statusText: "Server Error", body: "", headers: {})

    result = @sandbox.eval("fetch('https://api.example.com/data').ok")
    assert_equal false, result.value
  end

  def test_response_body
    queue_response(status: 200, statusText: "OK", body: "Hello World", headers: {})

    result = @sandbox.eval("fetch('https://api.example.com/data').body")
    assert_equal "Hello World", result.value
  end

  def test_response_empty_body
    queue_response(status: 204, statusText: "No Content", body: "", headers: {})

    result = @sandbox.eval("fetch('https://api.example.com/data').body")
    assert_equal "", result.value
  end

  def test_response_large_body
    large_body = "x" * 10000
    queue_response(status: 200, statusText: "OK", body: large_body, headers: {})

    result = @sandbox.eval("fetch('https://api.example.com/data').body")
    assert_equal large_body, result.value
  end

  def test_response_headers_object_exists
    result = @sandbox.eval("typeof fetch('https://api.example.com/data').headers")
    assert_equal "object", result.value
  end

  def test_response_all_properties
    queue_response(
      status: 201,
      statusText: "Created",
      body: '{"id": 123}',
      headers: { "content-type" => "application/json" }
    )

    result = @sandbox.eval(<<~JS)
      var response = fetch('https://api.example.com/users');
      JSON.stringify({
        status: response.status,
        statusText: response.statusText,
        ok: response.ok,
        body: response.body,
        hasHeaders: typeof response.headers === 'object'
      })
    JS

    data = JSON.parse(result.value)
    assert_equal 201, data['status']
    assert_equal "Created", data['statusText']
    assert_equal true, data['ok']
    assert_equal '{"id": 123}', data['body']
    assert_equal true, data['hasHeaders']
  end

  # ============================================================================
  # HTTP Status Code Tests
  # ============================================================================

  def test_status_200_ok
    queue_response(status: 200, statusText: "OK", body: "success", headers: {})
    result = @sandbox.eval("fetch('https://api.example.com/data').status")
    assert_equal 200, result.value
  end

  def test_status_201_created
    queue_response(status: 201, statusText: "Created", body: "", headers: {})
    result = @sandbox.eval("fetch('https://api.example.com/users').status")
    assert_equal 201, result.value
  end

  def test_status_204_no_content
    queue_response(status: 204, statusText: "No Content", body: "", headers: {})
    result = @sandbox.eval("fetch('https://api.example.com/users/1').status")
    assert_equal 204, result.value
  end

  def test_status_301_moved_permanently
    queue_response(status: 301, statusText: "Moved Permanently", body: "", headers: {})
    result = @sandbox.eval("fetch('https://api.example.com/old').status")
    assert_equal 301, result.value
  end

  def test_status_302_found
    queue_response(status: 302, statusText: "Found", body: "", headers: {})
    result = @sandbox.eval("fetch('https://api.example.com/redirect').status")
    assert_equal 302, result.value
  end

  def test_status_400_bad_request
    queue_response(status: 400, statusText: "Bad Request", body: "Invalid input", headers: {})
    result = @sandbox.eval("fetch('https://api.example.com/data').status")
    assert_equal 400, result.value
  end

  def test_status_401_unauthorized
    queue_response(status: 401, statusText: "Unauthorized", body: "", headers: {})
    result = @sandbox.eval("fetch('https://api.example.com/private').status")
    assert_equal 401, result.value
  end

  def test_status_403_forbidden
    queue_response(status: 403, statusText: "Forbidden", body: "", headers: {})
    result = @sandbox.eval("fetch('https://api.example.com/admin').status")
    assert_equal 403, result.value
  end

  def test_status_404_not_found
    queue_response(status: 404, statusText: "Not Found", body: "Not found", headers: {})
    result = @sandbox.eval("fetch('https://api.example.com/missing').status")
    assert_equal 404, result.value
  end

  def test_status_500_internal_server_error
    queue_response(status: 500, statusText: "Internal Server Error", body: "Error", headers: {})
    result = @sandbox.eval("fetch('https://api.example.com/error').status")
    assert_equal 500, result.value
  end

  def test_status_502_bad_gateway
    queue_response(status: 502, statusText: "Bad Gateway", body: "", headers: {})
    result = @sandbox.eval("fetch('https://api.example.com/proxy').status")
    assert_equal 502, result.value
  end

  def test_status_503_service_unavailable
    queue_response(status: 503, statusText: "Service Unavailable", body: "", headers: {})
    result = @sandbox.eval("fetch('https://api.example.com/data').status")
    assert_equal 503, result.value
  end

  # ============================================================================
  # JSON Parsing Tests
  # ============================================================================

  def test_parse_json_response
    queue_response(
      status: 200,
      statusText: "OK",
      body: '{"name": "John", "age": 30}',
      headers: { "content-type" => "application/json" }
    )

    result = @sandbox.eval(<<~JS)
      var response = fetch('https://api.example.com/user');
      var data = JSON.parse(response.body);
      data.name
    JS

    assert_equal "John", result.value
  end

  def test_parse_json_array_response
    queue_response(
      status: 200,
      statusText: "OK",
      body: '[{"id": 1}, {"id": 2}, {"id": 3}]',
      headers: { "content-type" => "application/json" }
    )

    result = @sandbox.eval(<<~JS)
      var response = fetch('https://api.example.com/users');
      var data = JSON.parse(response.body);
      data.length
    JS

    assert_equal 3, result.value
  end

  def test_parse_nested_json
    queue_response(
      status: 200,
      statusText: "OK",
      body: '{"user": {"name": "John", "address": {"city": "NYC"}}}',
      headers: {}
    )

    result = @sandbox.eval(<<~JS)
      var response = fetch('https://api.example.com/data');
      var data = JSON.parse(response.body);
      data.user.address.city
    JS

    assert_equal "NYC", result.value
  end

  def test_json_with_special_characters
    queue_response(
      status: 200,
      statusText: "OK",
      body: '{"message": "Hello \\"World\\"", "emoji": "😀"}',
      headers: {}
    )

    result = @sandbox.eval(<<~JS)
      var response = fetch('https://api.example.com/data');
      var data = JSON.parse(response.body);
      data.message
    JS

    assert_equal 'Hello "World"', result.value
  end

  # ============================================================================
  # URL Tests
  # ============================================================================

  def test_https_url
    result = @sandbox.eval("fetch('https://api.example.com/data').status")
    assert_equal 200, result.value
    assert_equal 'https://api.example.com/data', @http_requests[0][:url]
  end

  def test_http_url
    result = @sandbox.eval("fetch('http://api.example.com/data').status")
    assert_equal 200, result.value
    assert_equal 'http://api.example.com/data', @http_requests[0][:url]
  end

  def test_url_with_query_params
    result = @sandbox.eval("fetch('https://api.example.com/search?q=test&limit=10').status")
    assert_equal 200, result.value
    assert_equal 'https://api.example.com/search?q=test&limit=10', @http_requests[0][:url]
  end

  def test_url_with_port
    result = @sandbox.eval("fetch('https://api.example.com:8080/data').status")
    assert_equal 200, result.value
    assert_equal 'https://api.example.com:8080/data', @http_requests[0][:url]
  end

  def test_url_with_path_segments
    result = @sandbox.eval("fetch('https://api.example.com/v1/users/123/posts').status")
    assert_equal 200, result.value
    assert_equal 'https://api.example.com/v1/users/123/posts', @http_requests[0][:url]
  end

  def test_url_with_hash
    result = @sandbox.eval("fetch('https://example.com/page#section').status")
    assert_equal 200, result.value
    assert_equal 'https://example.com/page#section', @http_requests[0][:url]
  end

  # ============================================================================
  # Error Handling Tests
  # ============================================================================

  def test_error_missing_url
    error = assert_raises(MQuickJS::JavaScriptError) do
      @sandbox.eval("fetch()")
    end

    assert_match(/requires at least 1 argument/i, error.message)
  end

  def test_error_no_http_callback
    sandbox = MQuickJS::Sandbox.new
    # Don't set http_callback

    error = assert_raises(MQuickJS::JavaScriptError) do
      sandbox.eval("fetch('https://example.com')")
    end

    assert_match(/not enabled|callback not configured/i, error.message)
  end

  def test_error_invalid_url_type_number
    error = assert_raises(MQuickJS::JavaScriptError) do
      @sandbox.eval("fetch(123)")
    end

    # Should either convert to string or throw error
    # The implementation converts numbers to strings, so this actually succeeds
    # We document this behavior
  end

  def test_error_invalid_url_type_object
    error = assert_raises(MQuickJS::JavaScriptError) do
      @sandbox.eval("fetch({url: 'https://example.com'})")
    end

    # Objects get stringified to "[object Object]"
    # This is expected JavaScript behavior
  end

  def test_null_options
    result = @sandbox.eval("fetch('https://api.example.com/data', null).status")
    assert_equal 200, result.value
  end

  def test_undefined_options
    result = @sandbox.eval("fetch('https://api.example.com/data', undefined).status")
    assert_equal 200, result.value
  end

  def test_empty_options_object
    result = @sandbox.eval("fetch('https://api.example.com/data', {}).status")
    assert_equal 200, result.value
    assert_equal 'GET', @http_requests[0][:method]
  end

  # ============================================================================
  # Options Object Tests
  # ============================================================================

  def test_options_method_lowercase
    result = @sandbox.eval(<<~JS)
      fetch('https://api.example.com/data', { method: 'post' }).status
    JS

    assert_equal 200, result.value
    assert_equal 'post', @http_requests[0][:method]
  end

  def test_options_method_uppercase
    result = @sandbox.eval(<<~JS)
      fetch('https://api.example.com/data', { method: 'POST' }).status
    JS

    assert_equal 200, result.value
    assert_equal 'POST', @http_requests[0][:method]
  end

  def test_options_with_null_method
    result = @sandbox.eval(<<~JS)
      fetch('https://api.example.com/data', { method: null }).status
    JS

    assert_equal 200, result.value
    # Should default to GET when method is null
  end

  def test_options_with_undefined_method
    result = @sandbox.eval(<<~JS)
      fetch('https://api.example.com/data', { method: undefined }).status
    JS

    assert_equal 200, result.value
    # Should default to GET when method is undefined
  end

  def test_options_with_null_body
    result = @sandbox.eval(<<~JS)
      fetch('https://api.example.com/data', {
        method: 'POST',
        body: null
      }).status
    JS

    assert_equal 200, result.value
  end

  def test_options_with_undefined_body
    result = @sandbox.eval(<<~JS)
      fetch('https://api.example.com/data', {
        method: 'POST',
        body: undefined
      }).status
    JS

    assert_equal 200, result.value
  end

  def test_options_with_extra_properties
    result = @sandbox.eval(<<~JS)
      fetch('https://api.example.com/data', {
        method: 'POST',
        body: 'test',
        cache: 'no-cache',
        credentials: 'include',
        mode: 'cors'
      }).status
    JS

    assert_equal 200, result.value
    # Extra properties should be ignored
  end

  # ============================================================================
  # Multiple Request Tests
  # ============================================================================

  def test_multiple_sequential_requests
    queue_response(status: 200, statusText: "OK", body: "first", headers: {})
    queue_response(status: 201, statusText: "Created", body: "second", headers: {})
    queue_response(status: 202, statusText: "Accepted", body: "third", headers: {})

    result = @sandbox.eval(<<~JS)
      var r1 = fetch('https://api.example.com/1');
      var r2 = fetch('https://api.example.com/2');
      var r3 = fetch('https://api.example.com/3');
      r1.body + ',' + r2.body + ',' + r3.body
    JS

    assert_equal "first,second,third", result.value
    assert_equal 3, @http_requests.length
  end

  def test_request_in_function
    result = @sandbox.eval(<<~JS)
      function getData(url) {
        var response = fetch(url);
        return response.body;
      }
      getData('https://api.example.com/data')
    JS

    assert_equal '{"message": "success"}', result.value
  end

  def test_request_in_loop
    queue_response(status: 200, statusText: "OK", body: "a", headers: {})
    queue_response(status: 200, statusText: "OK", body: "b", headers: {})
    queue_response(status: 200, statusText: "OK", body: "c", headers: {})

    result = @sandbox.eval(<<~JS)
      var results = [];
      for (var i = 0; i < 3; i++) {
        var response = fetch('https://api.example.com/item/' + i);
        results.push(response.body);
      }
      results.join(',')
    JS

    assert_equal "a,b,c", result.value
    assert_equal 3, @http_requests.length
  end

  # ============================================================================
  # Edge Cases and Special Scenarios
  # ============================================================================

  def test_response_object_is_reusable
    result = @sandbox.eval(<<~JS)
      var response = fetch('https://api.example.com/data');
      var body1 = response.body;
      var body2 = response.body;
      var status1 = response.status;
      var status2 = response.status;
      body1 === body2 && status1 === status2
    JS

    assert_equal true, result.value
  end

  def test_response_properties_are_not_functions
    result = @sandbox.eval(<<~JS)
      var response = fetch('https://api.example.com/data');
      JSON.stringify({
        statusIsFunction: typeof response.status === 'function',
        bodyIsFunction: typeof response.body === 'function',
        okIsFunction: typeof response.ok === 'function'
      })
    JS

    data = JSON.parse(result.value)
    assert_equal false, data['statusIsFunction']
    assert_equal false, data['bodyIsFunction']
    assert_equal false, data['okIsFunction']
  end

  def test_response_can_be_stored_in_variable
    result = @sandbox.eval(<<~JS)
      var r1 = fetch('https://api.example.com/data');
      var r2 = r1;
      r2.status
    JS

    assert_equal 200, result.value
  end

  def test_response_can_be_passed_to_function
    result = @sandbox.eval(<<~JS)
      function getStatus(response) {
        return response.status;
      }
      var response = fetch('https://api.example.com/data');
      getStatus(response)
    JS

    assert_equal 200, result.value
  end

  def test_response_in_object
    result = @sandbox.eval(<<~JS)
      var result = {
        response: fetch('https://api.example.com/data')
      };
      result.response.status
    JS

    assert_equal 200, result.value
  end

  def test_response_in_array
    queue_response(status: 200, statusText: "OK", body: "a", headers: {})
    queue_response(status: 201, statusText: "Created", body: "b", headers: {})

    result = @sandbox.eval(<<~JS)
      var responses = [
        fetch('https://api.example.com/1'),
        fetch('https://api.example.com/2')
      ];
      responses[0].body + responses[1].body
    JS

    assert_equal "ab", result.value
  end

  def test_unicode_in_response_body
    queue_response(
      status: 200,
      statusText: "OK",
      body: '{"message": "こんにちは世界"}',
      headers: {}
    )

    result = @sandbox.eval(<<~JS)
      var response = fetch('https://api.example.com/data');
      var data = JSON.parse(response.body);
      data.message
    JS

    assert_equal "こんにちは世界", result.value
  end

  def test_empty_string_url
    result = @sandbox.eval("fetch('').status")
    assert_equal 200, result.value
    assert_equal '', @http_requests[0][:url]
  end

  def test_very_long_url
    long_url = "https://api.example.com/" + ("a" * 1000)

    result = @sandbox.eval("fetch('#{long_url}').status")
    assert_equal 200, result.value
    assert_equal long_url, @http_requests[0][:url]
  end

  # ============================================================================
  # Integration with Console Tests
  # ============================================================================

  def test_fetch_with_console_log
    result = @sandbox.eval(<<~JS)
      var response = fetch('https://api.example.com/data');
      console.log('Status:', response.status);
      response.body
    JS

    assert_equal '{"message": "success"}', result.value
    assert_includes result.console_output, 'Status:'
    assert_includes result.console_output, '200'
  end

  def test_logging_response_properties
    result = @sandbox.eval(<<~JS)
      var response = fetch('https://api.example.com/data');
      console.log('ok:', response.ok);
      console.log('status:', response.status);
      console.log('statusText:', response.statusText);
      'done'
    JS

    assert_equal 'done', result.value
    assert_includes result.console_output, 'ok: true'
    assert_includes result.console_output, 'status: 200'
    assert_includes result.console_output, 'statusText: OK'
  end

  # ============================================================================
  # Ruby Callback Integration Tests
  # ============================================================================

  def test_callback_receives_correct_method
    @sandbox.eval("fetch('https://api.example.com/data', { method: 'POST' })")
    assert_equal 'POST', @http_requests[0][:method]
  end

  def test_callback_receives_correct_url
    @sandbox.eval("fetch('https://api.example.com/users/123')")
    assert_equal 'https://api.example.com/users/123', @http_requests[0][:url]
  end

  def test_callback_receives_correct_body
    @sandbox.eval(<<~JS)
      fetch('https://api.example.com/users', {
        method: 'POST',
        body: 'test data'
      })
    JS

    assert_equal 'test data', @http_requests[0][:body]
  end

  def test_callback_receives_headers_object
    @sandbox.eval("fetch('https://api.example.com/data')")
    assert_kind_of Hash, @http_requests[0][:headers]
  end

  def test_callback_can_return_custom_status
    @sandbox.http_callback = lambda do |method, url, body, headers|
      { status: 418, statusText: "I'm a teapot", body: "☕", headers: {} }
    end

    result = @sandbox.eval(<<~JS)
      var response = fetch('https://api.example.com/coffee');
      JSON.stringify({
        status: response.status,
        statusText: response.statusText,
        body: response.body,
        ok: response.ok
      })
    JS

    data = JSON.parse(result.value)
    assert_equal 418, data['status']
    assert_equal "I'm a teapot", data['statusText']
    assert_equal "☕", data['body']
    assert_equal false, data['ok']
  end

  def test_callback_can_modify_response_based_on_method
    @sandbox.http_callback = lambda do |method, url, body, headers|
      case method
      when 'GET'
        { status: 200, statusText: "OK", body: "got", headers: {} }
      when 'POST'
        { status: 201, statusText: "Created", body: "created", headers: {} }
      when 'DELETE'
        { status: 204, statusText: "No Content", body: "", headers: {} }
      else
        { status: 405, statusText: "Method Not Allowed", body: "", headers: {} }
      end
    end

    result = @sandbox.eval(<<~JS)
      var r1 = fetch('https://api.example.com/data');
      var r2 = fetch('https://api.example.com/data', { method: 'POST' });
      var r3 = fetch('https://api.example.com/data', { method: 'DELETE' });
      JSON.stringify({
        get: r1.status,
        post: r2.status,
        delete: r3.status
      })
    JS

    data = JSON.parse(result.value)
    assert_equal 200, data['get']
    assert_equal 201, data['post']
    assert_equal 204, data['delete']
  end

  # ============================================================================
  # Case Sensitivity Tests
  # ============================================================================

  def test_method_case_preserved
    @sandbox.eval("fetch('https://example.com', { method: 'GeT' })")
    assert_equal 'GeT', @http_requests[0][:method]
  end

  def test_url_case_preserved
    @sandbox.eval("fetch('https://API.EXAMPLE.COM/Data')")
    assert_equal 'https://API.EXAMPLE.COM/Data', @http_requests[0][:url]
  end
end
