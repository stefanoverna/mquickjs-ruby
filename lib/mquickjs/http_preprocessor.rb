# frozen_string_literal: true

module MQuickJS
  # Pre-processes JavaScript code to handle HTTP calls
  # This is a Phase 1 implementation that works around mquickjs API limitations
  class HTTPPreprocessor
    def initialize(executor)
      @executor = executor
      @http_calls = []
    end

    attr_reader :http_calls

    # Transform JavaScript code with HTTP calls into executable code
    def process(code)
      # Simple pattern matching for http.get() and http.post()
      # This is a basic implementation - a full parser would be more robust

      result_code = code.dup
      call_index = 0

      # Match http.get('url') or http.get("url")
      result_code.gsub!(/http\.get\s*\(\s*['"]([^'"]+)['"]\s*\)/) do
        url = $1
        execute_and_inject('GET', url, nil, call_index)
        call_index += 1
        "_http_result_#{call_index - 1}"
      end

      # Match http.post('url', body)
      result_code.gsub!(/http\.post\s*\(\s*['"]([^'"]+)['"]\s*,\s*(.+?)\s*\)/) do
        url = $1
        body_expr = $2
        # For now, we'll need to evaluate the body expression separately
        # This is a limitation of the simple regex approach
        execute_and_inject('POST', url, body_expr, call_index)
        call_index += 1
        "_http_result_#{call_index - 1}"
      end

      result_code
    end

    private

    def execute_and_inject(method, url, body, index)
      # Execute HTTP request via Ruby
      response = @executor.execute(method, url, body: body)

      # Create JavaScript object representation
      # Inject this before the user code
      js_response = <<~JS.strip
        var _http_result_#{index} = {
          status: #{response[:status]},
          statusText: #{response[:statusText].to_json},
          ok: #{response[:status] >= 200 && response[:status] < 300},
          body: #{response[:body].to_json},
          headers: #{response[:headers].to_json},
          json: function() { return JSON.parse(this.body); },
          text: function() { return this.body; }
        };
      JS

      @http_calls << {
        method: method,
        url: url,
        response: response,
        injection: js_response
      }

      js_response
    end

    # Get all HTTP result injections to prepend to code
    def get_injections
      @http_calls.map { |call| call[:injection] }.join("\n")
    end
  end
end
