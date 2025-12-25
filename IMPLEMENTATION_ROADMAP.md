# HTTP JavaScript Integration - Implementation Roadmap

## Current Status

✅ **Complete:** Ruby HTTP infrastructure (HTTPConfig, HTTPExecutor)
⏳ **In Progress:** JavaScript integration

## Chosen Approach: Hybrid Solution

Given mquickjs API limitations, we'll implement a three-phase approach:

### Phase 1: Pre-processor Prototype (Immediate) ✅

**Goal:** Working HTTP from JavaScript using code transformation

```ruby
class MQuickJS::Sandbox
  def eval_with_http(code, http_config: nil)
    # 1. Parse JavaScript to extract http calls
    # 2. Execute HTTP calls in Ruby
    # 3. Inject results back into JavaScript
    # 4. Evaluate modified code
  end
end
```

**Example:**
```javascript
// Input JavaScript:
var response = http.get('https://api.example.com/data');
var user = response.json();

// Transformed to:
var _http_0 = {"status": 200, "body": "{...}"};  // Injected by Ruby
var response = _http_0;
var user = JSON.parse(_http_0.body);
```

**Pros:**
- Works immediately with current codebase
- No C code changes needed
- Full HTTP security enforcement
- Easy to test

**Cons:**
- Requires JavaScript parsing
- Less elegant than native integration
- Async patterns won't work

### Phase 2: Custom C Functions (Enhanced)

**Goal:** Add HTTP as global functions in C extension

**Implementation:**
```c
// Add to mquickjs_ext.c
static JSValue js_http_get(JSContext *ctx, JSValue *this_val, int argc, JSValue *argv) {
    // 1. Extract URL from argv[0]
    // 2. Call Ruby HTTPExecutor via rb_funcall
    // 3. Convert Ruby response hash to JSValue
    // 4. Return JSValue
}

// In sandbox_initialize:
void enable_http_functions(ContextWrapper *wrapper) {
    // Create global functions accessible from JavaScript
    // Note: Requires mquickjs function registration workaround
}
```

**Challenges:**
- mquickjs doesn't have `JS_NewCFunction`
- Need to use function pointers in stdlib table
- Requires modifying mqjs_stdlib.c

### Phase 3: Full mquickjs stdlib Integration (Complete)

**Goal:** Compile HTTP into mquickjs stdlib

**Steps:**
1. Modify `mqjs_stdlib.c` to add HTTP function table
2. Add HTTP functions alongside print, gc, etc.
3. Rebuild stdlib generator
4. Generate new mqjs_stdlib.h
5. Compile extension with HTTP support

**Code Changes:**
```c
// In mqjs_stdlib.c
const JSCFunctionDef js_http_funcs[] = {
    { "get", js_http_get, 1 },
    { "post", js_http_post, 2 },
    { "request", js_http_request, 1 },
};

// Register in stdlib
JS_SetPropertyStr(ctx, global, "http", http_obj);
```

## Recommended Implementation Order

### Immediate (This Session)
1. ✅ Create comprehensive tests for HTTP infrastructure
2. ⏳ Implement Phase 1 prototype (pre-processor)
3. ⏳ Add integration tests with real HTTP calls
4. ⏳ Document usage and limitations

### Short Term (Next Development Cycle)
1. Research mquickjs function registration internals
2. Implement Phase 2 (custom C functions)
3. Create benchmarks comparing approaches
4. Add more comprehensive security tests

### Long Term (Future Enhancement)
1. Contribute HTTP support back to mquickjs upstream
2. Implement Phase 3 (full stdlib integration)
3. Add WebSocket support
4. Add fetch() API compatibility

## Alternative: Upgrade to Full QuickJS

**Pros:**
- Complete JavaScript engine
- Full ES6+ support
- Dynamic function creation
- Active development

**Cons:**
- Larger memory footprint (~1MB vs ~100KB)
- May not meet "micro" requirement
- Different security model

## Decision Matrix

| Approach | Effort | Performance | Security | Elegance |
|----------|--------|-------------|----------|----------|
| Phase 1  | Low ⭐ | Medium ⭐⭐ | High ⭐⭐⭐ | Low ⭐ |
| Phase 2  | Medium ⭐⭐ | High ⭐⭐⭐ | High ⭐⭐⭐ | Medium ⭐⭐ |
| Phase 3  | High ⭐⭐⭐ | High ⭐⭐⭐ | High ⭐⭐⭐ | High ⭐⭐⭐ |
| QuickJS  | High ⭐⭐⭐ | High ⭐⭐⭐ | Medium ⭐⭐ | High ⭐⭐⭐ |

## Conclusion

**Recommended Path:**
1. Start with Phase 1 for immediate functionality
2. Gather user feedback and usage patterns
3. Invest in Phase 2/3 if HTTP is heavily used
4. Consider QuickJS if ES6+ features become critical

This provides a working solution now while maintaining a clear path to full integration.
