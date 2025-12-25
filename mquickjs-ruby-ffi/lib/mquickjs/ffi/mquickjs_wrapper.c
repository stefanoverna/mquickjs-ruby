/*
 * MQuickJS FFI Wrapper
 * Provides a simplified C API for FFI bindings
 */
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <sys/time.h>
#include "mquickjs.h"

// Context wrapper that includes memory buffer and console output
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
} ContextWrapper;

// Forward declaration
static void append_console_output(ContextWrapper *wrapper, const char *str, size_t len);
// Thread-local storage for current wrapper (for console.log capture)
static __thread ContextWrapper *current_wrapper = NULL;


// Stub functions required by mqjs_stdlib.h

static JSValue js_print(JSContext *ctx, JSValue *this_val, int argc, JSValue *argv) {
    // Capture console.log output
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
            // Convert to string
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
    // Disabled for security - no file loading in sandboxed code
    return JS_ThrowError(ctx, JS_CLASS_ERROR, "load() is disabled in sandbox mode");
}

static JSValue js_setTimeout(JSContext *ctx, JSValue *this_val, int argc, JSValue *argv) {
    // Disabled - no async operations in sandboxed code
    return JS_ThrowError(ctx, JS_CLASS_ERROR, "setTimeout() is disabled in sandbox mode");
}

static JSValue js_clearTimeout(JSContext *ctx, JSValue *this_val, int argc, JSValue *argv) {
    // Disabled - no async operations in sandboxed code
    return JS_ThrowError(ctx, JS_CLASS_ERROR, "clearTimeout() is disabled in sandbox mode");
}

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
            // Out of memory - can't append
            return;
        }
    }

    // Append the string
    memcpy(wrapper->console_output + wrapper->console_output_len, str, to_append);
    wrapper->console_output_len += to_append;
    wrapper->console_output[wrapper->console_output_len] = '\0';
}

// Create a new context with stdlib
ContextWrapper *mqjs_new_context(size_t mem_size, int64_t timeout_ms, size_t console_max_size) {
    ContextWrapper *wrapper = malloc(sizeof(ContextWrapper));
    if (!wrapper) return NULL;

    wrapper->mem_buf = malloc(mem_size);
    if (!wrapper->mem_buf) {
        free(wrapper);
        return NULL;
    }

    wrapper->mem_size = mem_size;
    wrapper->timeout_ms = timeout_ms;
    wrapper->timed_out = 0;
    wrapper->start_time_ms = 0;

    // Initialize console output buffer
    wrapper->console_max_size = console_max_size;
    wrapper->console_output_capacity = 1024; // Start with 1KB
    if (wrapper->console_output_capacity > console_max_size) {
        wrapper->console_output_capacity = console_max_size;
    }
    wrapper->console_output = malloc(wrapper->console_output_capacity + 1);
    if (!wrapper->console_output) {
        free(wrapper->mem_buf);
        free(wrapper);
        return NULL;
    }
    wrapper->console_output[0] = '\0';
    wrapper->console_output_len = 0;
    wrapper->console_truncated = 0;

    // Create context with stdlib
    wrapper->ctx = JS_NewContext(wrapper->mem_buf, mem_size, &js_stdlib);
    if (!wrapper->ctx) {
        free(wrapper->console_output);
        free(wrapper->mem_buf);
        free(wrapper);
        return NULL;
    }

    // Set interrupt handler for timeout
    JS_SetContextOpaque(wrapper->ctx, wrapper);
    JS_SetInterruptHandler(wrapper->ctx, interrupt_handler);

    return wrapper;
}

// Free context
void mqjs_free_context(ContextWrapper *wrapper) {
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

// Evaluate code
JSValue mqjs_eval(ContextWrapper *wrapper, const char *code, size_t code_len) {
    if (!wrapper || !wrapper->ctx) {
        return JS_EXCEPTION;
    }

    wrapper->start_time_ms = get_time_ms();
    wrapper->timed_out = 0;

    // Set current wrapper for console.log capture
    current_wrapper = wrapper;

    // Use JS_EVAL_RETVAL (1) to return the last value instead of undefined
    JSValue result = JS_Eval(wrapper->ctx, code, code_len, "<eval>", 1);

    // Clear current wrapper
    current_wrapper = NULL;

    return result;
}

// Check if execution timed out
int mqjs_timed_out(ContextWrapper *wrapper) {
    return wrapper ? wrapper->timed_out : 0;
}

// Get the JSContext from wrapper
JSContext *mqjs_get_context(ContextWrapper *wrapper) {
    return wrapper ? wrapper->ctx : NULL;
}

// Get console output
const char *mqjs_get_console_output(ContextWrapper *wrapper) {
    return wrapper ? wrapper->console_output : NULL;
}

// Get console output length
size_t mqjs_get_console_output_len(ContextWrapper *wrapper) {
    return wrapper ? wrapper->console_output_len : 0;
}

// Check if console output was truncated
int mqjs_console_truncated(ContextWrapper *wrapper) {
    return wrapper ? wrapper->console_truncated : 0;
}
