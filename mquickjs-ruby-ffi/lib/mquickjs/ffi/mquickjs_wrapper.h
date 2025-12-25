/*
 * MQuickJS FFI Wrapper Header
 */
#ifndef MQUICKJS_WRAPPER_H
#define MQUICKJS_WRAPPER_H

#include <stddef.h>
#include <stdint.h>
#include "mquickjs.h"

typedef struct ContextWrapper ContextWrapper;

// Create a new context with stdlib
ContextWrapper *mqjs_new_context(size_t mem_size, int64_t timeout_ms);

// Free context
void mqjs_free_context(ContextWrapper *wrapper);

// Evaluate code
JSValue mqjs_eval(ContextWrapper *wrapper, const char *code, size_t code_len);

// Check if execution timed out
int mqjs_timed_out(ContextWrapper *wrapper);

// Get the JSContext from wrapper
JSContext *mqjs_get_context(ContextWrapper *wrapper);

#endif /* MQUICKJS_WRAPPER_H */
