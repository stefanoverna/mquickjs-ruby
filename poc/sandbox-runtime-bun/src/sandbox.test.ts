/**
 * Tests for the Sandbox POC
 *
 * Run with: bun test
 */

import { describe, test, expect } from "bun:test";
import { Sandbox, evalJS } from "./sandbox";

describe("Sandbox", () => {
  describe("evalDirect", () => {
    test("evaluates simple expressions", async () => {
      const sandbox = new Sandbox();
      const result = await sandbox.evalDirect("1 + 2");
      expect(result.success).toBe(true);
      expect(result.result).toBe(3);
    });

    test("handles string results", async () => {
      const sandbox = new Sandbox();
      const result = await sandbox.evalDirect("'hello' + ' ' + 'world'");
      expect(result.success).toBe(true);
      expect(result.result).toBe("hello world");
    });

    test("handles object results", async () => {
      const sandbox = new Sandbox();
      const result = await sandbox.evalDirect("({ foo: 'bar', num: 42 })");
      expect(result.success).toBe(true);
      expect(result.result).toEqual({ foo: "bar", num: 42 });
    });

    test("catches JavaScript errors", async () => {
      const sandbox = new Sandbox();
      const result = await sandbox.evalDirect("throw new Error('test error')");
      expect(result.success).toBe(false);
      expect(result.error).toContain("test error");
    });

    test("catches reference errors", async () => {
      const sandbox = new Sandbox();
      const result = await sandbox.evalDirect("undefinedVariable");
      expect(result.success).toBe(false);
      expect(result.error).toBeDefined();
    });
  });

  describe("timeout", () => {
    test("terminates infinite loops", async () => {
      const sandbox = new Sandbox({ timeoutMs: 100 });
      const result = await sandbox.evalDirect("while(true) {}");
      expect(result.timedOut).toBe(true);
      expect(result.exitCode).not.toBe(0);
    });

    test("allows fast code to complete", async () => {
      const sandbox = new Sandbox({ timeoutMs: 5000 });
      const result = await sandbox.evalDirect("Array(1000).fill(0).reduce((a, b) => a + 1, 0)");
      expect(result.timedOut).toBe(false);
      expect(result.success).toBe(true);
      expect(result.result).toBe(1000);
    });
  });

  describe("console output", () => {
    test("truncates long output", async () => {
      const sandbox = new Sandbox({ consoleLogMaxSize: 100 });
      // Generate output longer than 100 chars
      const result = await sandbox.evalDirect(`
        for (let i = 0; i < 100; i++) {
          console.log('Line ' + i);
        }
        'done'
      `);
      // stdout should be truncated
      expect(result.stdout.length).toBeLessThanOrEqual(100);
    });
  });
});

describe("evalJS", () => {
  test("returns result on success", async () => {
    const result = await evalJS("Math.PI", { timeoutMs: 1000 });
    expect(result).toBeCloseTo(3.14159, 4);
  });

  test("throws on timeout", async () => {
    await expect(
      evalJS("while(true) {}", { timeoutMs: 100 })
    ).rejects.toThrow("TimeoutError");
  });

  test("throws on JavaScript error", async () => {
    await expect(
      evalJS("throw new Error('boom')", { timeoutMs: 1000 })
    ).rejects.toThrow("boom");
  });
});
