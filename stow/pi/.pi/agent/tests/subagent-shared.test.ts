import assert from "node:assert/strict";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import subagentExtension from "../extensions/subagent/index.ts";
import {
	assistantText,
	hasStoredTrustDecision,
	listRuns,
	readLatestAssistant,
	readMetadata,
	resolveRunState,
	updateMetadata,
	writeMetadata,
	type RunMetadata,
} from "../extensions/subagent/shared.ts";

function fixture(run: (root: string, metadata: RunMetadata) => void) {
	const root = mkdtempSync(join(tmpdir(), "pi-subagent-test-"));
	const previous = process.env.PI_CODING_AGENT_DIR;
	process.env.PI_CODING_AGENT_DIR = root;
	try {
		const now = new Date().toISOString();
		run(root, {
			version: 2,
			handle: "abc123",
			parentSessionId: "parent",
			runDir: join(root, "subagents", "runs", "abc123"),
			cwd: root,
			provider: "test",
			model: "test-model",
			thinking: "medium",
			state: "starting",
			hasStarted: false,
			createdAt: now,
			updatedAt: now,
		});
	} finally {
		if (previous === undefined) delete process.env.PI_CODING_AGENT_DIR;
		else process.env.PI_CODING_AGENT_DIR = previous;
		rmSync(root, { recursive: true, force: true });
	}
}

test("metadata updates preserve identity and parent-scoped listings", () => {
	fixture((_root, metadata) => {
		writeMetadata(metadata);
		const updated = updateMetadata(metadata.runDir, { state: "idle", handle: "wrong" });
		assert.equal(updated?.handle, metadata.handle);
		assert.equal(readMetadata(metadata.runDir)?.state, "idle");
		assert.equal(listRuns("parent").length, 1);
		assert.equal(listRuns("unrelated").length, 0);
	});
});

test("liveness distinguishes suspended, unavailable, and exited children", () => {
	fixture((_root, metadata) => {
		assert.equal(resolveRunState(metadata, "exited"), "starting");
		assert.equal(resolveRunState({ ...metadata, state: "idle", suspended: true }, "exited"), "idle");
		const active = { ...metadata, state: "busy" as const, terminal: { session: "s", window: "w", block: "b" } };
		assert.equal(resolveRunState(active, "unknown"), "busy");
		assert.equal(resolveRunState(active, "running"), "busy");
		assert.equal(resolveRunState(active, "exited"), "exited");
	});
});

test("latest response follows the active transcript branch and tolerates partial writes", () => {
	fixture((root) => {
		const transcript = join(root, "session.jsonl");
		const entry = (id: string, parentId: string | null, text: string) => ({
			type: "message", id, parentId,
			message: { role: "assistant", content: [{ type: "text", text }] },
		});
		writeFileSync(transcript, [
			JSON.stringify(entry("first", null, "first")),
			JSON.stringify(entry("abandoned", "first", "wrong branch")),
			JSON.stringify(entry("active", "first", "review complete")),
			'{"type":',
		].join("\n"));
		assert.equal(assistantText(readLatestAssistant(transcript)!), "review complete");
	});
});

test("trust detection respects stored ancestor decisions without granting trust", () => {
	fixture((root) => {
		assert.equal(hasStoredTrustDecision(join(root, "project")), false);
		writeFileSync(join(root, "trust.json"), JSON.stringify({ [root]: false }));
		assert.equal(hasStoredTrustDecision(join(root, "project")), true);
	});
});

test("parent extension exposes its bundled skill without starting processes", () => {
	const previous = process.env.PI_SUBAGENT_RUN_DIR;
	delete process.env.PI_SUBAGENT_RUN_DIR;
	try {
		const handlers = new Map<string, (...args: any[]) => any>();
		subagentExtension({ registerTool() {}, on: (name: string, handler: (...args: any[]) => any) => handlers.set(name, handler) } as any);
		const resources = handlers.get("resources_discover")!();
		assert.deepEqual(resources.skillPaths, [new URL("../extensions/subagent/skills", import.meta.url).pathname]);
		assert.ok(handlers.has("session_start"));
		assert.ok(handlers.has("session_shutdown"));
	} finally {
		if (previous !== undefined) process.env.PI_SUBAGENT_RUN_DIR = previous;
	}
});
