/**
 * Example usage of the Sandbox Runtime + Bun POC
 */

import { Sandbox, evalJS } from "./sandbox";

async function main() {
  console.log("=== Sandbox Runtime + Bun POC ===\n");

  // Example 1: Simple evaluation
  console.log("1. Simple evaluation:");
  const sandbox = new Sandbox({
    timeoutMs: 5000,
    memoryLimit: 50_000_000, // 50MB
  });

  const result1 = await sandbox.evalDirect("1 + 2 + 3");
  console.log("   Result:", result1);

  // Example 2: Timeout test
  console.log("\n2. Timeout test (should timeout):");
  const sandbox2 = new Sandbox({
    timeoutMs: 100, // Very short timeout
  });

  const result2 = await sandbox2.evalDirect("while(true) {}");
  console.log("   Timed out:", result2.timedOut);

  // Example 3: Using quick eval
  console.log("\n3. Quick eval:");
  try {
    const value = await evalJS("Math.PI * 2", { timeoutMs: 1000 });
    console.log("   Value:", value);
  } catch (e) {
    console.log("   Error:", e);
  }

  // Example 4: Console output
  console.log("\n4. Console output capture:");
  const result4 = await sandbox.evalDirect(`
    console.log("Hello from sandbox!");
    console.log("Another message");
    42
  `);
  console.log("   Stdout:", result4.stdout);

  console.log("\n=== POC Complete ===");
}

main().catch(console.error);
