/*
 * MQuickJS Native Ruby Extension
 * High-performance JavaScript sandbox for Ruby
 */

#include <ruby.h>
#include <ruby/encoding.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <sys/time.h>

// Include mquickjs after defining stub functions
static VALUE rb_cMQuickJS;
static VALUE rb_cSandbox;
static VALUE rb_cResult;
static VALUE rb_eMQuickJSSyntaxError;
static VALUE rb_eMQuickJSJavaScriptError;
static VALUE rb_eMQuickJSMemoryLimitError;
static VALUE rb_eMQuickJSTimeoutError;

// Forward declarations
typedef struct JSContext JSContext;
typedef uint64_t JSValue;

// Context wrapper structure
typedef struct {
    JSContext *ctx;
    uint8_t *mem_buf;
    size_t mem_size;
    int64_t start_time_ms;
    int64_t timeout_ms;
    int timed_out;
    char *console_output;
    size_t console_output_len;
    size_t console_output_capacity;
    size_t console_max_size;
    int console_truncated;
    VALUE rb_http_callback;  // Ruby callback for HTTP requests
} ContextWrapper;

// Thread-local storage for current wrapper
static __thread ContextWrapper *current_wrapper = NULL;

// Stub functions required by mqjs_stdlib.h
static void append_console_output(ContextWrapper *wrapper, const char *str, size_t len);

#include "mquickjs.h"

static JSValue js_print(JSContext *ctx, JSValue *this_val, int argc, JSValue *argv);
static JSValue js_gc(JSContext *ctx, JSValue *this_val, int argc, JSValue *argv);
static JSValue js_date_now(JSContext *ctx, JSValue *this_val, int argc, JSValue *argv);
static JSValue js_performance_now(JSContext *ctx, JSValue *this_val, int argc, JSValue *argv);
static JSValue js_load(JSContext *ctx, JSValue *this_val, int argc, JSValue *argv);
static JSValue js_setTimeout(JSContext *ctx, JSValue *this_val, int argc, JSValue *argv);
static JSValue js_clearTimeout(JSContext *ctx, JSValue *this_val, int argc, JSValue *argv);
static JSValue js_fetch(JSContext *ctx, JSValue *this_val, int argc, JSValue *argv);

// Include the standard library
#include "mqjs_stdlib.h"

// Get current time in milliseconds
static int64_t get_time_ms(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (int64_t)ts.tv_sec * 1000 + (ts.tv_nsec / 1000000);
}

// Interrupt handler for timeout
static int interrupt_handler(JSContext *ctx, void *opaque) {
    ContextWrapper *wrapper = (ContextWrapper *)opaque;

    if (wrapper->timeout_ms > 0) {
        int64_t elapsed = get_time_ms() - wrapper->start_time_ms;
        if (elapsed > wrapper->timeout_ms) {
            wrapper->timed_out = 1;
            return 1;  // Interrupt execution
        }
    }

    return 0;  // Continue execution
}

// Append to console output buffer
static void append_console_output(ContextWrapper *wrapper, const char *str, size_t len) {
    if (!wrapper || !str || len == 0) return;

    // Check if we've already exceeded the limit
    if (wrapper->console_output_len >= wrapper->console_max_size) {
        wrapper->console_truncated = 1;
        return;
    }

    // Calculate how much we can actually append
    size_t available = wrapper->console_max_size - wrapper->console_output_len;
    size_t to_append = len < available ? len : available;

    if (to_append < len) {
        wrapper->console_truncated = 1;
    }

    // Ensure we have enough capacity
    if (wrapper->console_output_len + to_append > wrapper->console_output_capacity) {
        size_t new_capacity = wrapper->console_output_capacity * 2;
        if (new_capacity > wrapper->console_max_size) {
            new_capacity = wrapper->console_max_size;
        }
        if (new_capacity < wrapper->console_output_len + to_append) {
            new_capacity = wrapper->console_output_len + to_append;
        }

        char *new_buffer = realloc(wrapper->console_output, new_capacity + 1);
        if (new_buffer) {
            wrapper->console_output = new_buffer;
            wrapper->console_output_capacity = new_capacity;
        } else {
            return;
        }
    }

    // Append the string
    memcpy(wrapper->console_output + wrapper->console_output_len, str, to_append);
    wrapper->console_output_len += to_append;
    wrapper->console_output[wrapper->console_output_len] = '\0';
}

// Stub function implementations
static JSValue js_print(JSContext *ctx, JSValue *this_val, int argc, JSValue *argv) {
    ContextWrapper *wrapper = current_wrapper;
    if (!wrapper) return JS_UNDEFINED;

    JSCStringBuf buf;
    for (int i = 0; i < argc; i++) {
        if (i > 0) {
            append_console_output(wrapper, " ", 1);
        }

        JSValue v = argv[i];
        if (JS_IsString(ctx, v)) {
            size_t len;
            const char *str = JS_ToCStringLen(ctx, &len, v, &buf);
            if (str) {
                append_console_output(wrapper, str, len);
            }
        } else {
            JSValue str_val = JS_ToString(ctx, v);
            if (!JS_IsException(str_val)) {
                size_t len;
                const char *str = JS_ToCStringLen(ctx, &len, str_val, &buf);
                if (str) {
                    append_console_output(wrapper, str, len);
                }
            }
        }
    }
    append_console_output(wrapper, "\n", 1);

    return JS_UNDEFINED;
}

static JSValue js_gc(JSContext *ctx, JSValue *this_val, int argc, JSValue *argv) {
    JS_GC(ctx);
    return JS_UNDEFINED;
}

static JSValue js_date_now(JSContext *ctx, JSValue *this_val, int argc, JSValue *argv) {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return JS_NewInt64(ctx, (int64_t)tv.tv_sec * 1000 + (tv.tv_usec / 1000));
}

static JSValue js_performance_now(JSContext *ctx, JSValue *this_val, int argc, JSValue *argv) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    int64_t ms = (int64_t)ts.tv_sec * 1000 + (ts.tv_nsec / 1000000);
    return JS_NewInt64(ctx, ms);
}

static JSValue js_load(JSContext *ctx, JSValue *this_val, int argc, JSValue *argv) {
    return JS_ThrowError(ctx, JS_CLASS_ERROR, "load() is disabled in sandbox mode");
}

static JSValue js_setTimeout(JSContext *ctx, JSValue *this_val, int argc, JSValue *argv) {
    return JS_ThrowError(ctx, JS_CLASS_ERROR, "setTimeout() is disabled in sandbox mode");
}

static JSValue js_clearTimeout(JSContext *ctx, JSValue *this_val, int argc, JSValue *argv) {
    return JS_ThrowError(ctx, JS_CLASS_ERROR, "clearTimeout() is disabled in sandbox mode");
}

// fetch() implementation
static JSValue js_fetch(JSContext *ctx, JSValue *this_val, int argc, JSValue *argv) {
    ContextWrapper *wrapper = current_wrapper;
    if (!wrapper) {
        return JS_ThrowError(ctx, JS_CLASS_ERROR, "fetch() called outside sandbox context");
    }

    if (wrapper->rb_http_callback == Qnil) {
        return JS_ThrowError(ctx, JS_CLASS_ERROR, "fetch() is not enabled - HTTP callback not configured");
    }

    // Parse arguments
    if (argc < 1) {
        return JS_ThrowError(ctx, JS_CLASS_TYPE_ERROR, "fetch() requires at least 1 argument (url)");
    }

    // Get URL
    JSCStringBuf url_buf;
    const char *url = JS_ToCString(ctx, argv[0], &url_buf);
    if (!url) {
        return JS_ThrowError(ctx, JS_CLASS_TYPE_ERROR, "fetch() url must be a string");
    }

    // Parse options (second argument)
    const char *method = "GET";
    const char *body = NULL;
    VALUE rb_headers = rb_hash_new();

    if (argc >= 2 && !JS_IsUndefined(argv[1]) && !JS_IsNull(argv[1])) {
        // Get method
        JSValue method_val = JS_GetPropertyStr(ctx, argv[1], "method");
        if (!JS_IsUndefined(method_val) && !JS_IsNull(method_val)) {
            JSCStringBuf method_buf;
            const char *method_str = JS_ToCString(ctx, method_val, &method_buf);
            if (method_str) {
                method = method_str;
            }
        }

        // Get body
        JSValue body_val = JS_GetPropertyStr(ctx, argv[1], "body");
        if (!JS_IsUndefined(body_val) && !JS_IsNull(body_val)) {
            JSCStringBuf body_buf;
            body = JS_ToCString(ctx, body_val, &body_buf);
        }

        // Get headers - skip for now
        // JSValue headers_val = JS_GetPropertyStr(ctx, argv[1], "headers");
    }

    // Call Ruby HTTP executor
    VALUE rb_url = rb_str_new2(url);
    VALUE rb_method = rb_str_new2(method);
    VALUE rb_body = body ? rb_str_new2(body) : Qnil;

    // Call the Ruby callback: http_callback.call(method, url, body, headers)
    VALUE rb_response = rb_funcall(wrapper->rb_http_callback, rb_intern("call"), 4,
                                     rb_method, rb_url, rb_body, rb_headers);

    // Extract response fields from Ruby hash
    VALUE rb_status = rb_hash_aref(rb_response, ID2SYM(rb_intern("status")));
    VALUE rb_status_text = rb_hash_aref(rb_response, ID2SYM(rb_intern("statusText")));
    VALUE rb_response_body = rb_hash_aref(rb_response, ID2SYM(rb_intern("body")));
    VALUE rb_response_headers = rb_hash_aref(rb_response, ID2SYM(rb_intern("headers")));

    int status = NIL_P(rb_status) ? 200 : NUM2INT(rb_status);
    const char *status_text = NIL_P(rb_status_text) ? "OK" : StringValueCStr(rb_status_text);
    const char *response_body = NIL_P(rb_response_body) ? "" : StringValueCStr(rb_response_body);

    // Create Response object
    JSValue response_obj = JS_NewObject(ctx);

    // Add properties
    JS_SetPropertyStr(ctx, response_obj, "status", JS_NewInt32(ctx, status));
    JS_SetPropertyStr(ctx, response_obj, "statusText", JS_NewString(ctx, status_text));
    JS_SetPropertyStr(ctx, response_obj, "ok", status >= 200 && status < 300 ? JS_TRUE : JS_FALSE);
    JS_SetPropertyStr(ctx, response_obj, "body", JS_NewString(ctx, response_body));

    // Add headers object (simplified - just store the body for now)
    JSValue headers_obj = JS_NewObject(ctx);
    JS_SetPropertyStr(ctx, response_obj, "headers", headers_obj);

    // Add text() method - returns body as-is
    // Note: We're storing the body as a property so text() can just return it
    // In a full implementation, we'd create actual method functions

    // Add json() method equivalent - we'll rely on users doing JSON.parse(response.body)
    // since we can't easily create function properties with mquickjs

    return response_obj;
}

// Response.text() helper - to be called as a separate function
static JSValue js_response_text(JSContext *ctx, JSValue *this_val, int argc, JSValue *argv) {
    if (argc < 1) {
        return JS_ThrowError(ctx, JS_CLASS_TYPE_ERROR, "responseText() requires a response object");
    }
    return JS_GetPropertyStr(ctx, argv[0], "body");
}

// Response.json() helper - to be called as a separate function
static JSValue js_response_json(JSContext *ctx, JSValue *this_val, int argc, JSValue *argv) {
    if (argc < 1) {
        return JS_ThrowError(ctx, JS_CLASS_TYPE_ERROR, "responseJson() requires a response object");
    }

    JSValue body = JS_GetPropertyStr(ctx, argv[0], "body");

    // Get the global object
    JSValue global = JS_GetGlobalObject(ctx);
    JSValue json_obj = JS_GetPropertyStr(ctx, global, "JSON");
    JSValue parse_func = JS_GetPropertyStr(ctx, json_obj, "parse");

    // Create arguments array for JSON.parse
    JSValue parse_argv[1] = { body };

    // Note: mquickjs doesn't have JS_Call in the same way as QuickJS
    // We'll need to use eval as a workaround
    // For now, just return the body and let users call JSON.parse manually

    return body;
}

// Ruby C API helper functions
static void sandbox_free(void *ptr) {
    ContextWrapper *wrapper = (ContextWrapper *)ptr;
    if (wrapper) {
        if (wrapper->ctx) {
            JS_FreeContext(wrapper->ctx);
        }
        if (wrapper->mem_buf) {
            free(wrapper->mem_buf);
        }
        if (wrapper->console_output) {
            free(wrapper->console_output);
        }
        free(wrapper);
    }
}

static size_t sandbox_memsize(const void *ptr) {
    const ContextWrapper *wrapper = (const ContextWrapper *)ptr;
    return sizeof(ContextWrapper) + (wrapper ? wrapper->mem_size : 0);
}

static const rb_data_type_t sandbox_type = {
    "MQuickJS::NativeSandbox",
    {NULL, sandbox_free, sandbox_memsize,},
    NULL, NULL,
    RUBY_TYPED_FREE_IMMEDIATELY,
};

// Allocate function for Ruby object
static VALUE sandbox_alloc(VALUE klass) {
    ContextWrapper *wrapper = malloc(sizeof(ContextWrapper));
    memset(wrapper, 0, sizeof(ContextWrapper));
    return TypedData_Wrap_Struct(klass, &sandbox_type, wrapper);
}

// Convert JavaScript value to Ruby value
static VALUE js_to_ruby(JSContext *ctx, JSValue val) {
    // Null
    if (val == JS_NULL) {
        return Qnil;
    }

    // Undefined
    if (val == JS_UNDEFINED) {
        return Qnil;
    }

    // Boolean
    if (val == JS_TRUE) {
        return Qtrue;
    }
    if (val == JS_FALSE) {
        return Qfalse;
    }

    // Exception
    if (val == JS_EXCEPTION) {
        return Qundef;
    }

    // Integer - check tag bits
    if ((val & 1) == 0) {  // JS_TAG_INT
        int32_t i = (int32_t)val >> 1;  // JS_VALUE_GET_INT
        return INT2NUM(i);
    }

    // Number (float)
    if (JS_IsNumber(ctx, val)) {
        double d;
        if (JS_ToNumber(ctx, &d, val) == 0) {
            return DBL2NUM(d);
        }
    }

    // String
    if (JS_IsString(ctx, val)) {
        JSCStringBuf buf;
        const char *str = JS_ToCString(ctx, val, &buf);
        if (str) {
            VALUE rb_str = rb_str_new2(str);
            rb_enc_associate(rb_str, rb_utf8_encoding());
            return rb_str;
        }
    }

    // Fallback: convert to string
    JSValue str_val = JS_ToString(ctx, val);
    if (!JS_IsException(str_val)) {
        JSCStringBuf buf;
        const char *str = JS_ToCString(ctx, str_val, &buf);
        if (str) {
            VALUE rb_str = rb_str_new2(str);
            rb_enc_associate(rb_str, rb_utf8_encoding());
            return rb_str;
        }
    }

    return Qnil;
}

// Convert Ruby value to JavaScript value
static JSValue ruby_to_js(JSContext *ctx, VALUE rb_val) {
    // nil -> null
    if (NIL_P(rb_val)) {
        return JS_NULL;
    }

    // Boolean -> true/false
    if (rb_val == Qtrue) {
        return JS_TRUE;
    }
    if (rb_val == Qfalse) {
        return JS_FALSE;
    }

    // Get Ruby type
    int type = TYPE(rb_val);

    // Integer -> number
    if (type == T_FIXNUM) {
        int64_t val = NUM2LL(rb_val);
        // Use Int32 for small integers, Int64 for larger ones
        if (val >= INT32_MIN && val <= INT32_MAX) {
            return JS_NewInt32(ctx, (int32_t)val);
        } else {
            return JS_NewInt64(ctx, val);
        }
    }

    // Float -> number
    if (type == T_FLOAT) {
        double val = NUM2DBL(rb_val);
        return JS_NewFloat64(ctx, val);
    }

    // String -> string
    if (type == T_STRING) {
        const char *str = StringValueCStr(rb_val);
        return JS_NewString(ctx, str);
    }

    // Symbol -> string
    if (type == T_SYMBOL) {
        const char *str = rb_id2name(SYM2ID(rb_val));
        return JS_NewString(ctx, str);
    }

    // Array -> array
    if (type == T_ARRAY) {
        long len = RARRAY_LEN(rb_val);
        JSValue js_array = JS_NewArray(ctx, (int)len);

        if (JS_IsException(js_array)) {
            return js_array;
        }

        for (long i = 0; i < len; i++) {
            VALUE rb_element = rb_ary_entry(rb_val, i);
            JSValue js_element = ruby_to_js(ctx, rb_element);

            if (JS_IsException(js_element)) {
                return js_element;
            }

            JS_SetPropertyUint32(ctx, js_array, (uint32_t)i, js_element);
        }

        return js_array;
    }

    // Hash -> object
    if (type == T_HASH) {
        JSValue js_obj = JS_NewObject(ctx);

        if (JS_IsException(js_obj)) {
            return js_obj;
        }

        // Helper struct for hash iteration
        struct hash_iter_data {
            JSContext *ctx;
            JSValue obj;
            int has_error;
        };

        struct hash_iter_data iter_data = {
            .ctx = ctx,
            .obj = js_obj,
            .has_error = 0
        };

        // Iteration callback
        int hash_foreach_cb(VALUE key, VALUE val, VALUE arg) {
            struct hash_iter_data *data = (struct hash_iter_data *)arg;

            if (data->has_error) {
                return ST_STOP;
            }

            // Convert key to string (symbols and strings are common)
            const char *key_str;
            VALUE key_str_val;

            if (TYPE(key) == T_SYMBOL) {
                key_str = rb_id2name(SYM2ID(key));
            } else if (TYPE(key) == T_STRING) {
                key_str = StringValueCStr(key);
            } else {
                // Convert other types to string
                key_str_val = rb_funcall(key, rb_intern("to_s"), 0);
                key_str = StringValueCStr(key_str_val);
            }

            // Convert value
            JSValue js_val = ruby_to_js(data->ctx, val);

            if (JS_IsException(js_val)) {
                data->has_error = 1;
                return ST_STOP;
            }

            // Set property
            JS_SetPropertyStr(data->ctx, data->obj, key_str, js_val);

            return ST_CONTINUE;
        }

        // Iterate over hash
        rb_hash_foreach(rb_val, hash_foreach_cb, (VALUE)&iter_data);

        if (iter_data.has_error) {
            return JS_EXCEPTION;
        }

        return js_obj;
    }

    // Unsupported type - convert to string representation
    VALUE rb_str = rb_funcall(rb_val, rb_intern("to_s"), 0);
    return JS_NewString(ctx, StringValueCStr(rb_str));
}

// Sandbox#initialize
static VALUE sandbox_initialize(int argc, VALUE *argv, VALUE self) {
    ContextWrapper *wrapper;
    TypedData_Get_Struct(self, ContextWrapper, &sandbox_type, wrapper);

    VALUE opts;
    rb_scan_args(argc, argv, "01", &opts);

    // Default values
    size_t memory_limit = 50000;
    int64_t timeout_ms = 5000;
    size_t console_max_size = 10000;

    // Parse options
    if (!NIL_P(opts)) {
        VALUE val;

        val = rb_hash_aref(opts, ID2SYM(rb_intern("memory_limit")));
        if (!NIL_P(val)) memory_limit = NUM2SIZET(val);

        val = rb_hash_aref(opts, ID2SYM(rb_intern("timeout_ms")));
        if (!NIL_P(val)) timeout_ms = NUM2LL(val);

        val = rb_hash_aref(opts, ID2SYM(rb_intern("console_log_max_size")));
        if (!NIL_P(val)) console_max_size = NUM2SIZET(val);
    }

    // Allocate memory buffer
    wrapper->mem_buf = malloc(memory_limit);
    if (!wrapper->mem_buf) {
        rb_raise(rb_eNoMemError, "Failed to allocate memory buffer");
    }

    wrapper->mem_size = memory_limit;
    wrapper->timeout_ms = timeout_ms;
    wrapper->timed_out = 0;
    wrapper->start_time_ms = 0;

    // Initialize console output buffer
    wrapper->console_max_size = console_max_size;
    wrapper->console_output_capacity = 1024;
    if (wrapper->console_output_capacity > console_max_size) {
        wrapper->console_output_capacity = console_max_size;
    }
    wrapper->console_output = malloc(wrapper->console_output_capacity + 1);
    if (!wrapper->console_output) {
        free(wrapper->mem_buf);
        free(wrapper);
        rb_raise(rb_eNoMemError, "Failed to allocate console output buffer");
    }
    wrapper->console_output[0] = '\0';
    wrapper->console_output_len = 0;
    wrapper->console_truncated = 0;
    wrapper->rb_http_callback = Qnil;

    // Create JS context
    wrapper->ctx = JS_NewContext(wrapper->mem_buf, memory_limit, &js_stdlib);
    if (!wrapper->ctx) {
        free(wrapper->console_output);
        free(wrapper->mem_buf);
        rb_raise(rb_eRuntimeError, "Failed to create JavaScript context");
    }

    // Set interrupt handler
    JS_SetContextOpaque(wrapper->ctx, wrapper);
    JS_SetInterruptHandler(wrapper->ctx, interrupt_handler);

    return self;
}

// Sandbox#http_callback=
static VALUE sandbox_set_http_callback(VALUE self, VALUE callback) {
    ContextWrapper *wrapper;
    TypedData_Get_Struct(self, ContextWrapper, &sandbox_type, wrapper);

    if (!wrapper) {
        rb_raise(rb_eRuntimeError, "Invalid sandbox state");
    }

    // Store the callback (Ruby will handle GC)
    wrapper->rb_http_callback = callback;

    return callback;
}

// Sandbox#eval
static VALUE sandbox_eval(VALUE self, VALUE code_str) {
    ContextWrapper *wrapper;
    TypedData_Get_Struct(self, ContextWrapper, &sandbox_type, wrapper);

    if (!wrapper || !wrapper->ctx) {
        rb_raise(rb_eRuntimeError, "Invalid sandbox state");
    }

    // Reset console output
    wrapper->console_output[0] = '\0';
    wrapper->console_output_len = 0;
    wrapper->console_truncated = 0;

    // Get code string
    const char *code = StringValueCStr(code_str);
    size_t code_len = RSTRING_LEN(code_str);

    // Set timing
    wrapper->start_time_ms = get_time_ms();
    wrapper->timed_out = 0;

    // Set current wrapper for console.log
    current_wrapper = wrapper;

    // Evaluate JavaScript
    JSValue result = JS_Eval(wrapper->ctx, code, code_len, "<eval>", 1);

    // Clear current wrapper
    current_wrapper = NULL;

    // Check for timeout
    if (wrapper->timed_out) {
        rb_raise(rb_eMQuickJSTimeoutError, "JavaScript execution timeout exceeded");
    }

    // Check for exception
    if (JS_IsException(result)) {
        JSValue exc = JS_GetException(wrapper->ctx);
        JSCStringBuf buf;
        const char *msg = JS_ToCString(wrapper->ctx, exc, &buf);

        // Determine error class
        int class_id = JS_GetClassID(wrapper->ctx, exc);
        int is_syntax_error = (class_id == 13 || (msg && strncmp(msg, "SyntaxError", 11) == 0));

        if (is_syntax_error) {
            rb_raise(rb_eMQuickJSSyntaxError, "%s", msg ? msg : "JavaScript error");
        } else {
            // For JavaScriptError, extract the stack trace
            VALUE rb_message = rb_str_new_cstr(msg ? msg : "JavaScript error");
            VALUE rb_stack = Qnil;

            // Try to get the stack property from the error object
            JSValue stack_val = JS_GetPropertyStr(wrapper->ctx, exc, "stack");
            if (!JS_IsUndefined(stack_val) && !JS_IsNull(stack_val)) {
                JSCStringBuf stack_buf;
                const char *stack_str = JS_ToCString(wrapper->ctx, stack_val, &stack_buf);
                if (stack_str) {
                    rb_stack = rb_str_new_cstr(stack_str);
                }
            }

            // Create JavaScriptError with message and stack
            VALUE argv[2] = { rb_message, rb_stack };
            VALUE exception = rb_class_new_instance(2, argv, rb_eMQuickJSJavaScriptError);
            rb_exc_raise(exception);
        }
    }

    // Convert result to Ruby
    VALUE rb_value = js_to_ruby(wrapper->ctx, result);

    // Create console output string
    VALUE console_output = rb_str_new(wrapper->console_output, wrapper->console_output_len);
    VALUE console_truncated = wrapper->console_truncated ? Qtrue : Qfalse;

    // Create Result object
    VALUE http_requests = rb_ary_new();  // Empty for now
    VALUE result_obj = rb_funcall(rb_cResult, rb_intern("new"), 4,
                                  rb_value, console_output, console_truncated, http_requests);

    return result_obj;
}

// Sandbox#set_variable
static VALUE sandbox_set_variable(VALUE self, VALUE name, VALUE value) {
    ContextWrapper *wrapper;
    TypedData_Get_Struct(self, ContextWrapper, &sandbox_type, wrapper);

    if (!wrapper || !wrapper->ctx) {
        rb_raise(rb_eRuntimeError, "Invalid sandbox state");
    }

    // Get variable name
    const char *var_name = StringValueCStr(name);

    // Validate variable name is not empty
    if (var_name[0] == '\0') {
        rb_raise(rb_eArgError, "Variable name cannot be empty");
    }

    // Convert Ruby value to JS value
    JSValue js_val = ruby_to_js(wrapper->ctx, value);

    if (JS_IsException(js_val)) {
        rb_raise(rb_eRuntimeError, "Failed to convert Ruby value to JavaScript value");
    }

    // Get global object
    JSValue global = JS_GetGlobalObject(wrapper->ctx);

    // Set property on global object
    JS_SetPropertyStr(wrapper->ctx, global, var_name, js_val);

    return value;
}

// Module initialization
void Init_mquickjs_native(void) {
    // Define module and classes
    rb_cMQuickJS = rb_define_module("MQuickJS");
    rb_cSandbox = rb_define_class_under(rb_cMQuickJS, "NativeSandbox", rb_cObject);
    rb_cResult = rb_const_get(rb_cMQuickJS, rb_intern("Result"));

    // Define exceptions
    rb_eMQuickJSSyntaxError = rb_const_get(rb_cMQuickJS, rb_intern("SyntaxError"));
    rb_eMQuickJSJavaScriptError = rb_const_get(rb_cMQuickJS, rb_intern("JavaScriptError"));
    rb_eMQuickJSMemoryLimitError = rb_const_get(rb_cMQuickJS, rb_intern("MemoryLimitError"));
    rb_eMQuickJSTimeoutError = rb_const_get(rb_cMQuickJS, rb_intern("TimeoutError"));

    // Define allocation and methods
    rb_define_alloc_func(rb_cSandbox, sandbox_alloc);
    rb_define_method(rb_cSandbox, "initialize", sandbox_initialize, -1);
    rb_define_method(rb_cSandbox, "eval", sandbox_eval, 1);
    rb_define_method(rb_cSandbox, "set_variable", sandbox_set_variable, 2);
    rb_define_method(rb_cSandbox, "http_callback=", sandbox_set_http_callback, 1);
}
