/**
 * Ruby Bridge - How this could integrate with Ruby
 *
 * This file demonstrates how the sandbox-runtime + Bun approach
 * could be exposed to Ruby, similar to how mquickjs-ruby works.
 */

import { Sandbox, type SandboxOptions, type SandboxResult } from "./sandbox";

/**
 * JSON-based protocol for Ruby <-> Bun communication
 *
 * Ruby would spawn this as a subprocess and communicate via stdin/stdout
 */

interface Request {
  id: string;
  action: "eval" | "create_sandbox" | "destroy_sandbox";
  code?: string;
  options?: SandboxOptions;
  sandbox_id?: string;
}

interface Response {
  id: string;
  success: boolean;
  result?: unknown;
  error?: string;
  sandbox_id?: string;
}

const sandboxes = new Map<string, Sandbox>();

async function handleRequest(request: Request): Promise<Response> {
  try {
    switch (request.action) {
      case "create_sandbox": {
        const id = `sandbox-${Date.now()}-${Math.random().toString(36).slice(2)}`;
        const sandbox = new Sandbox(request.options);
        sandboxes.set(id, sandbox);
        return { id: request.id, success: true, sandbox_id: id };
      }

      case "eval": {
        if (!request.sandbox_id || !request.code) {
          return { id: request.id, success: false, error: "Missing sandbox_id or code" };
        }
        const sandbox = sandboxes.get(request.sandbox_id);
        if (!sandbox) {
          return { id: request.id, success: false, error: "Sandbox not found" };
        }
        // Use evalDirect for POC (no sandbox-runtime dependency)
        const result = await sandbox.evalDirect(request.code);
        if (result.timedOut) {
          return { id: request.id, success: false, error: "TimeoutError" };
        }
        if (result.memoryExceeded) {
          return { id: request.id, success: false, error: "MemoryLimitError" };
        }
        return {
          id: request.id,
          success: result.success,
          result: result.result,
          error: result.error,
        };
      }

      case "destroy_sandbox": {
        if (request.sandbox_id) {
          sandboxes.delete(request.sandbox_id);
        }
        return { id: request.id, success: true };
      }

      default:
        return { id: request.id, success: false, error: "Unknown action" };
    }
  } catch (e) {
    return {
      id: request.id,
      success: false,
      error: e instanceof Error ? e.message : String(e),
    };
  }
}

/**
 * Main loop for Ruby subprocess communication
 */
async function main() {
  const decoder = new TextDecoder();
  const encoder = new TextEncoder();

  // Read from stdin line by line
  for await (const chunk of Bun.stdin.stream()) {
    const lines = decoder.decode(chunk).split("\n").filter(Boolean);

    for (const line of lines) {
      try {
        const request: Request = JSON.parse(line);
        const response = await handleRequest(request);
        process.stdout.write(JSON.stringify(response) + "\n");
      } catch (e) {
        process.stdout.write(
          JSON.stringify({
            id: "unknown",
            success: false,
            error: `Parse error: ${e}`,
          }) + "\n"
        );
      }
    }
  }
}

// Only run main if this is the entry point
if (import.meta.main) {
  main().catch(console.error);
}
