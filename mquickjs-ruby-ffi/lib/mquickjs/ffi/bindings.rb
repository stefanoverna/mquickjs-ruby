# frozen_string_literal: true

require 'ffi'

module MQuickJS
  module FFI
    # FFI bindings to libmquickjs
    module Bindings
      extend ::FFI::Library

      # Load the shared library
      lib_path = File.expand_path('../libmquickjs.so', __FILE__)
      ffi_lib lib_path

      # Opaque types
      typedef :pointer, :JSContext
      typedef :pointer, :ContextWrapper

      # Value type (uint32_t or uint64_t depending on architecture)
      if ::FFI::Platform::ADDRESS_SIZE == 64
        typedef :uint64, :JSValue
      else
        typedef :uint32, :JSValue
      end

      # Tag special bits
      JS_TAG_SPECIAL_BITS = 5

      # Tags
      JS_TAG_SPECIAL = 3
      JS_TAG_BOOL = JS_TAG_SPECIAL | (0 << 2)   # 3
      JS_TAG_NULL = JS_TAG_SPECIAL | (1 << 2)   # 7
      JS_TAG_UNDEFINED = JS_TAG_SPECIAL | (2 << 2)  # 11
      JS_TAG_EXCEPTION = JS_TAG_SPECIAL | (3 << 2)  # 15

      # Constants
      JS_NULL = JS_TAG_NULL | (0 << JS_TAG_SPECIAL_BITS)   # 7
      JS_UNDEFINED = JS_TAG_UNDEFINED | (0 << JS_TAG_SPECIAL_BITS)  # 11
      JS_TRUE = JS_TAG_BOOL | (1 << JS_TAG_SPECIAL_BITS)   # 35
      JS_FALSE = JS_TAG_BOOL | (0 << JS_TAG_SPECIAL_BITS)  # 3
      JS_EXCEPTION = JS_TAG_EXCEPTION | (0 << JS_TAG_SPECIAL_BITS)  # 15

      # Tag constants
      JS_TAG_INT = 0
      JS_TAG_PTR = 1

      # Error classes
      JS_CLASS_ERROR = 9
      JS_CLASS_SYNTAX_ERROR = 13

      # Wrapper functions (simplified API)
      attach_function :mqjs_new_context, [:size_t, :int64, :size_t], :ContextWrapper
      attach_function :mqjs_free_context, [:ContextWrapper], :void
      attach_function :mqjs_eval, [:ContextWrapper, :string, :size_t], :JSValue
      attach_function :mqjs_timed_out, [:ContextWrapper], :int
      attach_function :mqjs_get_context, [:ContextWrapper], :JSContext
      attach_function :mqjs_get_console_output, [:ContextWrapper], :string
      attach_function :mqjs_get_console_output_len, [:ContextWrapper], :size_t
      attach_function :mqjs_console_truncated, [:ContextWrapper], :int

      # Core JS functions
      attach_function :JS_GetException, [:JSContext], :JSValue
      attach_function :JS_IsNumber, [:JSContext, :JSValue], :int
      attach_function :JS_IsString, [:JSContext, :JSValue], :int
      attach_function :JS_GetClassID, [:JSContext, :JSValue], :int
      attach_function :JS_ToNumber, [:JSContext, :pointer, :JSValue], :int
      attach_function :JS_ToCString, [:JSContext, :JSValue, :pointer], :string
      attach_function :JS_ToString, [:JSContext, :JSValue], :JSValue

      # Helper to check if value is an exception
      def self.is_exception?(value)
        value == JS_EXCEPTION
      end

      # Helper to check if value is null
      def self.is_null?(value)
        value == JS_NULL
      end

      # Helper to check if value is undefined
      def self.is_undefined?(value)
        value == JS_UNDEFINED
      end

      # Helper to check if value is int
      def self.is_int?(value)
        (value & 1) == JS_TAG_INT
      end

      # Helper to get int value
      def self.get_int(value)
        value >> 1
      end

      # Helper to check if value is bool
      def self.is_bool?(value)
        value == JS_TRUE || value == JS_FALSE
      end

      # Helper to get bool value
      def self.get_bool(value)
        value == JS_TRUE
      end
    end
  end
end
