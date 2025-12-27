/**
 * Sandbox Runtime + Bun POC
 *
 * This module explores using @anthropic-ai/sandbox-runtime with Bun
 * as an alternative to mquickjs-ruby for sandboxed JavaScript execution.
 */

import { spawn, type Subprocess } from "bun";

export interface SandboxOptions {
  /**
   * Memory limit in bytes.
   * Uses BUN_JSC_forceRAMSize environment variable (soft limit via GC pressure)
   * For hard limits, requires OS-level cgroups.
   */
  memoryLimit?: number;

  /**
   * Execution timeout in milliseconds.
   * Uses Bun.spawn's timeout option.
   */
  timeoutMs?: number;

  /**
   * Maximum console output size in bytes.
   * Uses Bun.spawn's maxBuffer option.
   */
  consoleLogMaxSize?: number;

  /**
   * Network configuration for sandbox-runtime
   */
  network?: {
    allowedDomains?: string[];
    deniedDomains?: string[];
  };

  /**
   * Filesystem configuration for sandbox-runtime
   */
  filesystem?: {
    denyRead?: string[];
    allowWrite?: string[];
    denyWrite?: string[];
  };
}

export interface SandboxResult {
  success: boolean;
  result?: unknown;
  error?: string;
  stdout: string;
  stderr: string;
  timedOut: boolean;
  memoryExceeded: boolean;
  exitCode: number | null;
}

export class Sandbox {
  private options: Required<SandboxOptions>;

  constructor(options: SandboxOptions = {}) {
    this.options = {
      memoryLimit: options.memoryLimit ?? 50_000_000, // 50MB default (vs mquickjs 50KB)
      timeoutMs: options.timeoutMs ?? 5_000,
      consoleLogMaxSize: options.consoleLogMaxSize ?? 10_000,
      network: options.network ?? { allowedDomains: [], deniedDomains: [] },
      filesystem: options.filesystem ?? { denyRead: [], allowWrite: [], denyWrite: [] },
    };
  }

  /**
   * Execute JavaScript code in a sandboxed environment.
   *
   * This uses sandbox-runtime for filesystem/network isolation
   * and Bun for execution with resource limits.
   */
  async eval(code: string): Promise<SandboxResult> {
    // Create a temporary file with the code to execute
    const tempFile = `/tmp/sandbox-${Date.now()}-${Math.random().toString(36).slice(2)}.js`;

    // Wrap code to capture result and console output
    const wrappedCode = `
      const __originalConsoleLog = console.log;
      const __originalConsoleError = console.error;
      const __consoleOutput = [];

      console.log = (...args) => {
        __consoleOutput.push({ type: 'log', args: args.map(String) });
      };
      console.error = (...args) => {
        __consoleOutput.push({ type: 'error', args: args.map(String) });
      };

      try {
        const __result = await (async () => {
          ${code}
        })();
        console.log = __originalConsoleLog;
        console.log(JSON.stringify({
          success: true,
          result: __result,
          console: __consoleOutput
        }));
      } catch (e) {
        console.log = __originalConsoleLog;
        console.log(JSON.stringify({
          success: false,
          error: e.message,
          stack: e.stack,
          console: __consoleOutput
        }));
      }
    `;

    await Bun.write(tempFile, wrappedCode);

    try {
      // Build the command with sandbox-runtime wrapper
      const srtCommand = this.buildSrtCommand(tempFile);

      const proc = spawn({
        cmd: srtCommand,
        env: {
          ...process.env,
          // Set memory limit via JavaScriptCore environment variable
          BUN_JSC_forceRAMSize: String(this.options.memoryLimit),
        },
        timeout: this.options.timeoutMs,
        // maxBuffer limits stdout/stderr capture
        // Note: Bun's maxBuffer is per-stream, not total
      });

      const stdout = await new Response(proc.stdout).text();
      const stderr = await new Response(proc.stderr).text();
      const exitCode = await proc.exited;

      // Check for timeout (exit code 124 or killed by signal)
      const timedOut = exitCode === 124 || exitCode === 143;

      // Check for OOM (exit code 137 = killed by SIGKILL, often OOM)
      const memoryExceeded = exitCode === 137;

      // Parse result from stdout
      let result: SandboxResult = {
        success: false,
        stdout: stdout.slice(0, this.options.consoleLogMaxSize),
        stderr: stderr.slice(0, this.options.consoleLogMaxSize),
        timedOut,
        memoryExceeded,
        exitCode,
      };

      if (!timedOut && !memoryExceeded && stdout) {
        try {
          const parsed = JSON.parse(stdout.trim());
          result.success = parsed.success;
          result.result = parsed.result;
          result.error = parsed.error;
        } catch {
          result.error = `Failed to parse output: ${stdout}`;
        }
      }

      return result;
    } finally {
      // Clean up temp file
      try {
        await Bun.write(tempFile, ""); // Clear content
        const fs = await import("fs/promises");
        await fs.unlink(tempFile);
      } catch {
        // Ignore cleanup errors
      }
    }
  }

  /**
   * Build the sandbox-runtime (srt) command with all configurations
   */
  private buildSrtCommand(scriptPath: string): string[] {
    const srtArgs: string[] = ["srt"];

    // Add network restrictions
    if (this.options.network.allowedDomains?.length) {
      // sandbox-runtime uses a settings file for complex configs
      // For POC, we'll use the basic command structure
    }

    // The actual command to run inside the sandbox
    srtArgs.push("bun", "run", scriptPath);

    return srtArgs;
  }

  /**
   * Alternative: Direct execution without sandbox-runtime
   * (for comparison/testing purposes)
   */
  async evalDirect(code: string): Promise<SandboxResult> {
    const tempFile = `/tmp/sandbox-direct-${Date.now()}.js`;

    const wrappedCode = `
      try {
        const result = eval(${JSON.stringify(code)});
        console.log(JSON.stringify({ success: true, result }));
      } catch (e) {
        console.log(JSON.stringify({ success: false, error: e.message }));
      }
    `;

    await Bun.write(tempFile, wrappedCode);

    try {
      const proc = spawn({
        cmd: ["bun", "run", tempFile],
        env: {
          ...process.env,
          BUN_JSC_forceRAMSize: String(this.options.memoryLimit),
        },
        timeout: this.options.timeoutMs,
      });

      const stdout = await new Response(proc.stdout).text();
      const stderr = await new Response(proc.stderr).text();
      const exitCode = await proc.exited;

      const timedOut = exitCode === 124 || exitCode === 143;
      const memoryExceeded = exitCode === 137;

      let result: SandboxResult = {
        success: false,
        stdout,
        stderr,
        timedOut,
        memoryExceeded,
        exitCode,
      };

      if (stdout) {
        try {
          const parsed = JSON.parse(stdout.trim());
          result.success = parsed.success;
          result.result = parsed.result;
          result.error = parsed.error;
        } catch {
          result.error = `Failed to parse: ${stdout}`;
        }
      }

      return result;
    } finally {
      try {
        const fs = await import("fs/promises");
        await fs.unlink(tempFile);
      } catch {}
    }
  }
}

/**
 * Quick eval function similar to MQuickJS.eval()
 */
export async function evalJS(
  code: string,
  options?: SandboxOptions
): Promise<unknown> {
  const sandbox = new Sandbox(options);
  const result = await sandbox.eval(code);

  if (result.timedOut) {
    throw new Error("TimeoutError: Execution timed out");
  }
  if (result.memoryExceeded) {
    throw new Error("MemoryLimitError: Memory limit exceeded");
  }
  if (!result.success) {
    throw new Error(result.error || "Unknown error");
  }

  return result.result;
}
