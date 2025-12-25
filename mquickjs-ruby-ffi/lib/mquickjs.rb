# frozen_string_literal: true

require_relative 'mquickjs/version'
require_relative 'mquickjs/errors'
require_relative 'mquickjs/ffi/bindings'
require_relative 'mquickjs/ffi/sandbox'

module MQuickJS
  # Alias for the FFI implementation (will be configurable later)
  Sandbox = FFI::Sandbox

  # Convenience method for one-shot evaluation
  #
  # @param code [String] JavaScript code to evaluate
  # @param memory_limit [Integer] Memory limit in bytes (default: 50KB)
  # @param timeout_ms [Integer] Timeout in milliseconds (default: 5000ms)
  # @return [Object] Result of the evaluation, converted to Ruby type
  # @raise [SyntaxError] If the code has a syntax error
  # @raise [JavaScriptError] If the code throws an error
  # @raise [MemoryLimitError] If memory limit is exceeded
  # @raise [TimeoutError] If execution timeout is exceeded
  def self.eval(code, memory_limit: 50_000, timeout_ms: 5000)
    sandbox = Sandbox.new(memory_limit: memory_limit, timeout_ms: timeout_ms)
    sandbox.eval(code)
  end
end
