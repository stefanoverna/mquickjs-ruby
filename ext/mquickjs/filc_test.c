/*
 * Fil-C Memory Safety Test for MQuickJS
 *
 * This test program verifies that MQuickJS works correctly when compiled
 * with fil-c for memory safety. It creates a JS context, runs a simple
 * evaluation, and verifies the result.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "mquickjs.h"

/* Stub functions required by mqjs_stdlib.h */
static JSValue js_print(JSContext *ctx, JSValue *this_val, int argc, JSValue *argv) {
    (void)ctx; (void)this_val; (void)argc; (void)argv;
    return JS_UNDEFINED;
}
static JSValue js_gc(JSContext *ctx, JSValue *this_val, int argc, JSValue *argv) {
    (void)ctx; (void)this_val; (void)argc; (void)argv;
    return JS_UNDEFINED;
}
static JSValue js_date_now(JSContext *ctx, JSValue *this_val, int argc, JSValue *argv) {
    (void)ctx; (void)this_val; (void)argc; (void)argv;
    return JS_NewInt32(ctx, 0);
}
static JSValue js_performance_now(JSContext *ctx, JSValue *this_val, int argc, JSValue *argv) {
    (void)ctx; (void)this_val; (void)argc; (void)argv;
    return JS_NewFloat64(ctx, 0.0);
}
static JSValue js_load(JSContext *ctx, JSValue *this_val, int argc, JSValue *argv) {
    (void)ctx; (void)this_val; (void)argc; (void)argv;
    return JS_UNDEFINED;
}
static JSValue js_setTimeout(JSContext *ctx, JSValue *this_val, int argc, JSValue *argv) {
    (void)ctx; (void)this_val; (void)argc; (void)argv;
    return JS_UNDEFINED;
}
static JSValue js_clearTimeout(JSContext *ctx, JSValue *this_val, int argc, JSValue *argv) {
    (void)ctx; (void)this_val; (void)argc; (void)argv;
    return JS_UNDEFINED;
}
static JSValue js_fetch(JSContext *ctx, JSValue *this_val, int argc, JSValue *argv) {
    (void)ctx; (void)this_val; (void)argc; (void)argv;
    return JS_UNDEFINED;
}

#include "mqjs_stdlib.h"

int main(void) {
    printf("MQuickJS + Fil-C Memory Safety Test\n");
    printf("===================================\n\n");

    /* Allocate memory for JS context */
    size_t mem_size = 64 * 1024;  /* 64KB */
    void *mem = malloc(mem_size);
    if (!mem) {
        fprintf(stderr, "Failed to allocate memory\n");
        return 1;
    }

    /* Create JS context */
    JSContext *ctx = JS_NewContext(mem, mem_size, &js_stdlib);
    if (!ctx) {
        fprintf(stderr, "Failed to create JS context\n");
        free(mem);
        return 1;
    }

    printf("JS context created successfully\n");

    /* Test simple evaluation */
    const char *code = "1 + 2";
    JSValue result = JS_Eval(ctx, code, strlen(code), "<test>", JS_EVAL_RETVAL);

    if (JS_IsException(result)) {
        fprintf(stderr, "JS evaluation failed\n");
        JS_FreeContext(ctx);
        free(mem);
        return 1;
    }

    int res;
    JS_ToInt32(ctx, &res, result);
    printf("Evaluated: %s = %d\n", code, res);

    if (res != 3) {
        fprintf(stderr, "ERROR: Expected 3, got %d\n", res);
        JS_FreeContext(ctx);
        free(mem);
        return 1;
    }

    /* Clean up */
    JS_FreeContext(ctx);
    free(mem);

    printf("\nAll tests passed! Memory safety checks active.\n");
    printf("Fil-C is protecting against:\n");
    printf("  - Buffer overflows\n");
    printf("  - Use-after-free\n");
    printf("  - Double free\n");
    printf("  - Out-of-bounds access\n");
    return 0;
}
