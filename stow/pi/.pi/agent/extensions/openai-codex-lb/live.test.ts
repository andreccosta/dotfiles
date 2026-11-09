import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { test } from "node:test";

const agentDir = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const enabled = process.env.CODEX_LB_LIVE_TEST === "1";

// Real, billable requests; only the harmless diagnostic tool is exposed to Pi.
// Both nonce-bearing instructions and two successive tool results must survive.
for (const [transport, wire, fast, reconnect] of [
	["responses", "sse", false, false],
	["codex", "sse", false, false],
	["codex", "websocket-cached", false, false],
	["codex", "websocket-cached", true, false],
	["codex", "websocket-cached", false, true],
] as const) {
	test(`live Pi ${transport}/${wire}${fast ? " fast alias" : ""}${reconnect ? " reconnect" : ""}: instructions and two tool turns`, {
		skip: !enabled, timeout: 150000,
	}, async () => {
		assert.ok(process.env.CODEX_LB_API_KEY, "Set CODEX_LB_API_KEY for the live test");
		const root = mkdtempSync(join(tmpdir(), "pi-codex-lb-live-"));
		try {
			writeFileSync(join(root, "settings.json"), JSON.stringify({ transport: wire, packages: [], enableInstallTelemetry: false }));
			writeFileSync(join(root, "models.json"), readFileSync(join(agentDir, "models.json")));
			const baseModel = process.env.CODEX_LB_TEST_MODEL ?? "gpt-6.1-sol";
			const model = fast ? `${baseModel}-fast` : baseModel;
			const args = ["--no-extensions", "--no-mcp", "--no-skills", "--no-prompt-templates", "--no-approve", "--no-session", "--no-builtin-tools",
				"-e", join(agentDir, "extensions/openai-codex-lb/index.ts"),
				"-e", join(agentDir, "extensions/openai-fast-aliases.ts"),
				"-e", join(agentDir, "tests/fixtures/codex-lb-probe.ts"),
				"--provider", "work", "--model", model, "--thinking", "low", "-p", "Run the diagnostic now."];
			const result = await new Promise<{ code: number | null; stdout: string; stderr: string }>((resolveResult, reject) => {
				const child = spawn(process.env.PI_TEST_BIN ?? "pi", args, {
					cwd: root,
					env: { ...process.env, PI_CODING_AGENT_DIR: root, CODEX_LB_TRANSPORT: transport, CODEX_LB_PROBE_RECONNECT: reconnect ? "1" : "0" },
					stdio: ["ignore", "pipe", "pipe"],
				});
				let stdout = "", stderr = "";
				const timer = setTimeout(() => child.kill("SIGKILL"), 140000);
				child.stdout.on("data", (chunk) => { stdout += chunk; });
				child.stderr.on("data", (chunk) => { stderr += chunk; });
				child.on("error", (error) => { clearTimeout(timer); reject(error); });
				child.on("close", (code) => { clearTimeout(timer); resolveResult({ code, stdout, stderr }); });
			});
			assert.equal(result.code, 0, result.stderr);
			assert.doesNotMatch(result.stderr, /Failed to load extension/);
			const marker = result.stderr.split("\n").find((line) => line.startsWith("CODEX_LB_PROBE "));
			assert.ok(marker, `Probe did not complete: ${result.stderr}\n${result.stdout}`);
			const probe = JSON.parse(marker.slice("CODEX_LB_PROBE ".length));
			assert.equal(probe.calls, 2, result.stdout);
			assert.equal(probe.payloads, 3);
			assert.equal(probe.priorityPayloads, fast ? 3 : 0);
			assert.equal(result.stdout.trim(), probe.expected, result.stdout);
			if (wire === "websocket-cached") {
				assert.ok(probe.stats?.connectionsCreated >= 1, JSON.stringify(probe.stats));
				assert.ok(probe.stats?.connectionsReused >= 1, JSON.stringify(probe.stats));
				assert.equal(probe.stats?.sseFallbacks, 0, JSON.stringify(probe.stats));
				assert.ok(probe.stats?.deltaRequests >= 1, JSON.stringify(probe.stats));
				if (reconnect) assert.equal(probe.stats?.connectionsCreated, 2, JSON.stringify(probe.stats));
			}
			console.log(`${transport}/${wire}${fast ? " fast" : ""}: ${JSON.stringify(probe.stats ?? { toolCalls: probe.calls })}`);
		} finally {
			rmSync(root, { recursive: true, force: true });
		}
	});
}
