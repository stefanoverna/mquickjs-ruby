# frozen_string_literal: true

require_relative 'bindings'

module MQuickJS
  module FFI
    # FFI-based Sandbox implementation
    class Sandbox
      DEFAULT_MEMORY_LIMIT = 50_000  # 50KB
      DEFAULT_TIMEOUT_MS = 5000      # 5 seconds

      attr_reader :memory_limit, :timeout_ms

      def initialize(memory_limit: DEFAULT_MEMORY_LIMIT, timeout_ms: DEFAULT_TIMEOUT_MS)
        @memory_limit = memory_limit
        @timeout_ms = timeout_ms
      end

      def eval(code)
        raise ArgumentError, "code must be a String" unless code.is_a?(String)

        # Create context wrapper
        wrapper = Bindings.mqjs_new_context(@memory_limit, @timeout_ms)
        raise MemoryLimitError, "Failed to create context" if wrapper.null?

        begin
          # Evaluate the code
          result_val = Bindings.mqjs_eval(wrapper, code, code.bytesize)

          # Check for timeout
          if Bindings.mqjs_timed_out(wrapper) != 0
            raise TimeoutError, "Execution exceeded #{@timeout_ms}ms timeout"
          end

          # Check for exception
          if Bindings.is_exception?(result_val)
            ctx = Bindings.mqjs_get_context(wrapper)
            handle_exception(ctx)
          end

          # Convert result to Ruby value
          ctx = Bindings.mqjs_get_context(wrapper)
          js_to_ruby(ctx, result_val)
        ensure
          Bindings.mqjs_free_context(wrapper) unless wrapper.null?
        end
      end

      private

      def handle_exception(ctx)
        exc_val = Bindings.JS_GetException(ctx)

        # Get the error message
        msg_val = Bindings.JS_ToString(ctx, exc_val)
        message = if Bindings.is_exception?(msg_val)
          "Unknown error"
        else
          buf = ::FFI::MemoryPointer.new(:uint8, 5)
          str = Bindings.JS_ToCString(ctx, msg_val, buf)
          str || "Unknown error"
        end

        # Determine error type from class ID or message
        class_id = Bindings.JS_GetClassID(ctx, exc_val)
        error_class = if class_id == Bindings::JS_CLASS_SYNTAX_ERROR || message.start_with?("SyntaxError")
          SyntaxError
        else
          JavaScriptError
        end

        raise error_class, message
      end

      def js_to_ruby(ctx, value)
        # Handle special values
        return nil if Bindings.is_null?(value) || Bindings.is_undefined?(value)
        return Bindings.get_bool(value) if Bindings.is_bool?(value)

        # Handle integers
        if Bindings.is_int?(value)
          return Bindings.get_int(value)
        end

        # Handle numbers (floats)
        if Bindings.JS_IsNumber(ctx, value) != 0
          num_ptr = ::FFI::MemoryPointer.new(:double)
          if Bindings.JS_ToNumber(ctx, num_ptr, value) == 0
            num = num_ptr.read_double
            # Return integer if it's a whole number
            return num.to_i if num == num.to_i
            return num
          end
        end

        # Handle strings
        if Bindings.JS_IsString(ctx, value) != 0
          buf = ::FFI::MemoryPointer.new(:uint8, 5)
          str = Bindings.JS_ToCString(ctx, value, buf)
          return str.force_encoding('UTF-8') if str
        end

        # Default: try to convert to string
        str_val = Bindings.JS_ToString(ctx, value)
        unless Bindings.is_exception?(str_val)
          buf = ::FFI::MemoryPointer.new(:uint8, 5)
          str = Bindings.JS_ToCString(ctx, str_val, buf)
          return str.force_encoding('UTF-8') if str
        end

        nil
      end
    end
  end
end
