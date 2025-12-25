# frozen_string_literal: true

module MQuickJS
  # Result of evaluating JavaScript code
  class Result
    attr_reader :value, :console_output

    def initialize(value, console_output, console_truncated)
      @value = value
      @console_output = console_output
      @console_truncated = console_truncated
    end

    def console_truncated?
      @console_truncated
    end
  end
end
