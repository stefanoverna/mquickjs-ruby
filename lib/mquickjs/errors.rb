# frozen_string_literal: true

module MQuickJS
  # Base error class for all MQuickJS errors
  class Error < StandardError; end

  # Raised when JavaScript code has a syntax error
  class SyntaxError < Error
    attr_reader :stack

    def initialize(message, stack = nil)
      super(message)
      @stack = stack
    end
  end

  # Raised when JavaScript code throws an error
  class JavaScriptError < Error
    attr_reader :stack

    def initialize(message, stack = nil)
      super(message)
      @stack = stack
    end
  end

  # Raised when memory limit is exceeded
  class MemoryLimitError < Error; end

  # Raised when execution timeout is exceeded
  class TimeoutError < Error; end

  # Raised when HTTP request is blocked by whitelist
  class HTTPBlockedError < Error; end

  # Raised when HTTP request limit is exceeded
  class HTTPLimitError < Error; end

  # Raised when HTTP request fails
  class HTTPError < Error; end

  # Raised when invalid arguments are passed
  class ArgumentError < Error; end
end
