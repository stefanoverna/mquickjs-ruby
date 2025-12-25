# frozen_string_literal: true

require_relative 'mquickjs/version'
require_relative 'mquickjs/errors'
require_relative 'mquickjs/result'
require_relative 'mquickjs/http_config'
require_relative 'mquickjs/http_executor'
require_relative 'mquickjs/mquickjs_native'
require_relative 'mquickjs/sandbox'

module MQuickJS
  # Convenience method for one-shot evaluation
  #
  # @param code [String] JavaScript code to evaluate
  # @param memory_limit [Integer] Memory limit in bytes (default: 50KB)
  # @param timeout_ms [Integer] Timeout in milliseconds (default: 5000ms)
  # @param http [Hash, nil] HTTP configuration options (enables fetch() in JavaScript)
  # @return [Result] Result object with value, console_output, etc.
  def self.eval(code, memory_limit: 50_000, timeout_ms: 5000, http: nil)
    sandbox = Sandbox.new(memory_limit: memory_limit, timeout_ms: timeout_ms, http: http)
    sandbox.eval(code)
  end
end
