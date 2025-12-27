# Sandbox Runtime + Bun vs mquickjs-ruby: Feasibility Analysis

## Executive Summary

This POC explores using [@anthropic-ai/sandbox-runtime](https://github.com/anthropic-experimental/sandbox-runtime) combined with [Bun](https://bun.sh) as an alternative to mquickjs-ruby for sandboxed JavaScript execution.

**Key Finding**: The combination can achieve most isolation goals but has significant gaps in resource limiting compared to mquickjs-ruby's fine-grained control.

---

## Limit Comparison Matrix

| Limit | mquickjs-ruby | sandbox-runtime + Bun | Gap Analysis |
|-------|---------------|----------------------|--------------|
| **Memory Limit** | ✅ Hard limit (default 50KB) | ⚠️ Soft limit via `BUN_JSC_forceRAMSize` | Bun's limit is a GC hint, not enforced. Need cgroups for hard limits. |
| **Execution Timeout** | ✅ Precise (default 5s, interrupt-based) | ✅ `Bun.spawn({ timeout })` | Works but less precise (process-level vs instruction-level) |
| **Console Output Limit** | ✅ 10KB default, truncated | ⚠️ Manual truncation needed | Can be implemented in wrapper |
| **Filesystem Isolation** | ✅ Complete (no fs access) | ✅ sandbox-runtime deny/allow patterns | sandbox-runtime is more flexible |
| **Network Isolation** | ✅ Whitelist-based fetch only | ✅ sandbox-runtime domain filtering | sandbox-runtime provides similar control |
| **HTTP Request Limits** | ✅ max_requests, timeouts, sizes | ❌ Not built-in | Would need custom implementation |
| **Private IP Blocking** | ✅ Built-in | ⚠️ Requires custom proxy config | Possible but more complex |
| **Stack Depth Limit** | ✅ Hard limit (8 levels) | ❌ No control | V8/JSC have their own limits |
| **String Size Limit** | ✅ Hard limit (2GB) | ❌ Engine default | Not configurable |
| **eval() Blocking** | ✅ Completely disabled | ❌ Available by default | Would need code transformation |

---

## Detailed Analysis

### 1. Memory Limits

**mquickjs-ruby**: Uses a fixed-size memory buffer (default 50KB). When exhausted, raises `MemoryLimitError`. This is a **hard limit** enforced at the allocator level.

**Bun**: Uses `BUN_JSC_forceRAMSize` environment variable which tells JavaScriptCore's GC what RAM to assume. This is a **soft limit** - it increases GC pressure at ~80% usage but doesn't prevent allocation.

```typescript
// Bun approach (soft limit)
spawn({
  cmd: ["bun", "run", script],
  env: { BUN_JSC_forceRAMSize: "52428800" } // 50MB
});
```

**To achieve hard limits**, you'd need:
- Linux: cgroups v2 memory controller
- macOS: No reliable user-space mechanism

```bash
# Linux cgroups example (requires root or delegation)
cgcreate -g memory:sandbox
cgset -r memory.max=52428800 sandbox
cgexec -g memory:sandbox bun run script.js
```

### 2. Execution Timeout

**mquickjs-ruby**: Interrupt-based, checked every ~10,000 operations. Very precise.

**Bun**: Process-level timeout via `Bun.spawn({ timeout })`. Sends SIGTERM then SIGKILL.

```typescript
const proc = spawn({
  cmd: ["bun", "run", script],
  timeout: 5000, // 5 seconds
});
```

**Gap**: Bun's timeout is less precise for tight loops but adequate for most use cases.

### 3. Filesystem Isolation

**mquickjs-ruby**: No filesystem APIs exposed. Complete isolation by design.

**sandbox-runtime**: Configurable deny/allow patterns using OS primitives (sandbox-exec on macOS, bubblewrap on Linux).

```json
{
  "filesystem": {
    "denyRead": ["~/.ssh", "~/.aws"],
    "allowWrite": ["./output"],
    "denyWrite": [".env", "*.key"]
  }
}
```

**Verdict**: sandbox-runtime is actually **more flexible** - you can allow controlled access rather than none.

### 4. Network Isolation

**mquickjs-ruby**: HTTP-only via `fetch()` with Ruby callback. Supports whitelisting, private IP blocking, request/response size limits.

**sandbox-runtime**: Domain-based allow/deny lists via HTTP/SOCKS5 proxy.

```json
{
  "network": {
    "allowedDomains": ["api.example.com", "cdn.example.com"],
    "deniedDomains": ["*.internal.corp"]
  }
}
```

**Gaps**:
- No built-in request counting (`max_requests`)
- No per-request timeout control
- No request/response size limits
- Private IP blocking requires custom proxy configuration

### 5. Console Output

**mquickjs-ruby**: Bounded buffer (default 10KB), automatically truncated.

**Bun**: No built-in limit. Would need manual implementation:

```typescript
const stdout = await new Response(proc.stdout).text();
const truncated = stdout.slice(0, 10_000);
```

---

## Architecture Comparison

### mquickjs-ruby Architecture

```
┌─────────────────────────────────────┐
│           Ruby Process              │
│  ┌───────────────────────────────┐  │
│  │    mquickjs C Extension       │  │
│  │  ┌─────────────────────────┐  │  │
│  │  │   QuickJS Engine        │  │  │
│  │  │   (50KB memory pool)    │  │  │
│  │  └─────────────────────────┘  │  │
│  │  • Interrupt handler          │  │
│  │  • Memory allocator hooks     │  │
│  │  • No external processes      │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
```

**Pros**: Single process, low overhead, precise control
**Cons**: Limited JS features, custom build

### sandbox-runtime + Bun Architecture

```
┌─────────────────────────────────────┐
│           Ruby Process              │
│  ┌───────────────────────────────┐  │
│  │    Ruby Gem (FFI/Subprocess)  │  │
│  └───────────────┬───────────────┘  │
└──────────────────┼──────────────────┘
                   │ spawn
┌──────────────────▼──────────────────┐
│         sandbox-runtime (srt)        │
│  ┌───────────────────────────────┐  │
│  │   OS Sandbox                  │  │
│  │   (sandbox-exec / bubblewrap) │  │
│  │  ┌─────────────────────────┐  │  │
│  │  │      Bun Runtime        │  │  │
│  │  │   (JavaScriptCore)      │  │  │
│  │  └─────────────────────────┘  │  │
│  └───────────────────────────────┘  │
│  ┌───────────────────────────────┐  │
│  │   HTTP/SOCKS5 Proxy           │  │
│  │   (Network filtering)         │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
```

**Pros**: Full JS features, modern APIs, OS-level isolation
**Cons**: Multiple processes, higher overhead, less precise limits

---

## Performance Considerations

| Metric | mquickjs-ruby | sandbox-runtime + Bun |
|--------|---------------|----------------------|
| Cold start | ~1-5ms | ~8-50ms (Bun) + srt overhead |
| Memory baseline | ~50KB | ~20MB (Bun minimal) |
| Execution speed | Slower (interpreter) | Faster (JIT) |
| Process overhead | None (in-process) | Subprocess spawn |

**Trade-off**: sandbox-runtime + Bun is slower to start but faster for complex computations.

---

## Implementation Requirements

To match mquickjs-ruby's capabilities, you'd need:

### Must Have
1. ✅ Basic sandbox-runtime + Bun integration
2. ✅ Timeout via `Bun.spawn({ timeout })`
3. ⚠️ Memory limits via cgroups (Linux only)
4. ✅ Console output truncation

### Should Have
5. ❌ HTTP request counting and limits
6. ❌ Request/response size enforcement
7. ⚠️ Private IP blocking (custom proxy)
8. ❌ Precise instruction-level timeout

### Nice to Have
9. ❌ Stack depth control
10. ❌ eval() blocking (code transformation)

---

## Recommendation

### Use sandbox-runtime + Bun if:
- You need modern JavaScript features (ES2024+, async/await, etc.)
- Execution speed matters more than startup time
- You're running on Linux with cgroup access
- You can accept ~20MB memory baseline per sandbox
- Network isolation (domain-based) is sufficient

### Keep mquickjs-ruby if:
- You need precise, hard memory limits (especially <1MB)
- Sub-millisecond startup is required
- You need HTTP-level controls (request counting, size limits)
- You're running on macOS or without cgroup access
- Minimal attack surface is critical

---

## Files in This POC

- `src/sandbox.ts` - Main sandbox wrapper combining Bun limits with sandbox-runtime
- `src/example.ts` - Usage examples
- `src/ruby-bridge.ts` - How Ruby could communicate with this via subprocess

## Next Steps

1. **Test sandbox-runtime integration** - Install `@anthropic-ai/sandbox-runtime` and test actual isolation
2. **Implement cgroups wrapper** - For hard memory limits on Linux
3. **Build HTTP proxy layer** - For request counting and size limits
4. **Benchmark comparison** - Cold start, execution speed, memory usage
5. **Ruby gem prototype** - FFI or subprocess-based integration
