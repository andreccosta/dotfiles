import assert from "node:assert/strict";
import { existsSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import subagentExtension, { deliverEvents } from "../extensions/subagent/index.ts";
import {
	assistantText,
	collectEventBatch,
	EVENT_EXCERPT_LIMIT,
	eventsDir,
	hasStoredTrustDecision,
	inboxDir,
	isCrashed,
	listRuns,
	readLatestAssistant,
	readMetadata,
	readPendingEvents,
	removeEventsForEntry,
	resolveRunState,
	stoppingRuns,
	turnEvent,
	updateMetadata,
	writeEvent,
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

function assistant(id: string, text: string, stopReason = "stop") {
	return { type: "message", id, parentId: null, message: { role: "assistant", content: [{ type: "text", text }], stopReason } };
}

test("turn events classify the latest response and cap excerpts", () => {
	fixture((_root, metadata) => {
		const run = { ...metadata, name: "review" };
		const latest = (stopReason: string, text = "done") => {
			const entry = assistant("e1", text, stopReason);
			return { id: entry.id, message: entry.message as any };
		};
		assert.deepEqual(turnEvent(run, latest("stop"), true, false, "/s.jsonl"), {
			handle: "abc123", name: "review", kind: "completed", entryId: "e1", excerpt: "done", sessionFile: "/s.jsonl",
		});
		assert.equal(turnEvent(run, latest("error"), true, false, undefined).kind, "failed");
		assert.equal(turnEvent(run, latest("aborted"), true, false, undefined).kind, "aborted");
		assert.equal(turnEvent(run, latest("stop"), true, true, undefined).kind, "aborted");
		const stale = turnEvent(run, latest("stop"), false, true, undefined);
		assert.equal(stale.kind, "aborted");
		assert.equal(stale.entryId, undefined);
		assert.equal(stale.excerpt, undefined);
		const long = turnEvent(run, latest("stop", "x".repeat(EVENT_EXCERPT_LIMIT + 10)), true, false, "/s.jsonl");
		assert.ok(long.excerpt!.startsWith("x".repeat(EVENT_EXCERPT_LIMIT) + "\n[Truncated"));
		assert.ok(long.excerpt!.includes("/s.jsonl"));
	});
});

test("child writes turn events on settle, skipping stale, superseded, and opted-out turns", () => {
	fixture((_root, metadata) => {
		const previous = process.env.PI_SUBAGENT_RUN_DIR;
		process.env.PI_SUBAGENT_RUN_DIR = metadata.runDir;
		const handlers = new Map<string, (...args: any[]) => any>();
		try {
			writeMetadata(metadata);
			subagentExtension({ on: (name: string, handler: any) => handlers.set(name, handler), setSessionName() {}, sendUserMessage() {} } as any);
			const branch: unknown[] = [assistant("old", "previous response")];
			const ctx = {
				isIdle: () => true,
				sessionManager: { getBranch: () => branch, getSessionFile: () => "/child.jsonl", getSessionId: () => "child" },
			};
			const settle = (aborted = false) => {
				handlers.get("agent_start")!({}, ctx);
				handlers.get("agent_settled")!({ aborted }, ctx);
			};
			const events = () => readPendingEvents("parent").map(({ event }) => event);
			// Resume does not report the existing response.
			handlers.get("session_start")!({}, ctx);
			assert.deepEqual(events(), []);

			settle(true);
			assert.deepEqual(events(), [{ handle: "abc123", kind: "aborted", sessionFile: "/child.jsonl" }]);
			rmSync(eventsDir("parent"), { recursive: true });

			branch.push(assistant("new", "fresh response"));
			settle();
			assert.deepEqual(events(), [{ handle: "abc123", kind: "completed", entryId: "new", excerpt: "fresh response", sessionFile: "/child.jsonl" }]);
			assert.equal(readMetadata(metadata.runDir)?.state, "idle");
			// Aborted again before a new response: do not resend the stale one.
			settle(true);
			assert.equal(events()[1].entryId, undefined);
			rmSync(eventsDir("parent"), { recursive: true });

			mkdirSync(inboxDir(metadata.runDir), { recursive: true });
			writeFileSync(join(inboxDir(metadata.runDir), "1.json"), JSON.stringify({ message: "next", delivery: "auto" }));
			branch.push(assistant("superseded", "x"));
			settle();
			assert.deepEqual(events(), []);
			rmSync(inboxDir(metadata.runDir), { recursive: true });

			updateMetadata(metadata.runDir, { notify: false });
			branch.push(assistant("quiet", "x"));
			settle();
			assert.deepEqual(events(), []);
		} finally {
			handlers.get("session_shutdown")?.({ reason: "reload" });
			if (previous === undefined) delete process.env.PI_SUBAGENT_RUN_DIR;
			else process.env.PI_SUBAGENT_RUN_DIR = previous;
		}
	});
});

test("parent batches events within budget and defers the rest", () => {
	fixture(() => {
		for (const id of ["a", "b", "c"]) writeEvent("parent", { handle: "h1", kind: "completed", entryId: id, excerpt: id.repeat(3000) });
		const sent: any[] = [];
		const pi = { sendMessage: (message: any, options: any) => sent.push({ message, options }) } as any;
		const idle = { isIdle: () => true };
		deliverEvents(pi, "parent", { isIdle: () => false });
		assert.equal(sent.length, 0);
		assert.equal(readPendingEvents("parent").length, 3);
		deliverEvents(pi, "parent", idle);
		assert.equal(sent.length, 1);
		assert.deepEqual(sent[0].options, { deliverAs: "followUp", triggerTurn: true });
		assert.equal(sent[0].message.customType, "subagent-events");
		assert.deepEqual(sent[0].message.details, { events: [{ handle: "h1", kind: "completed", entryId: "a" }, { handle: "h1", kind: "completed", entryId: "b" }] });
		assert.ok(sent[0].message.content.startsWith("Subagent h1 finished a turn [entry a]:\naaa"));
		assert.deepEqual(readPendingEvents("parent").map(({ event }) => event.entryId), ["c"]);
		deliverEvents(pi, "parent", idle);
		assert.equal(sent.length, 2);
		assert.equal(existsSync(eventsDir("parent")), false);
		deliverEvents(pi, "parent", idle);
		assert.equal(sent.length, 2);
	});
});

test("wait drops only the pending event of the response it returned", () => {
	fixture(() => {
		writeEvent("parent", { handle: "h1", kind: "completed", entryId: "seen", excerpt: "x" });
		writeEvent("parent", { handle: "h2", kind: "completed", entryId: "fresh", excerpt: "y" });
		assert.deepEqual(readPendingEvents("parent").map(({ event }) => event.handle), ["h1", "h2"]);
		// Only the returned entry of the waited handle is dropped.
		removeEventsForEntry("parent", "h2", "seen");
		removeEventsForEntry("parent", "h1", "other");
		assert.equal(readPendingEvents("parent").length, 2);
		removeEventsForEntry("parent", "h1", "seen");
		assert.deepEqual(collectEventBatch("parent").events.map(({ event }) => event.handle), ["h2"]);
		removeEventsForEntry("parent", "h2", "fresh");
		assert.equal(existsSync(eventsDir("parent")), false);
	});
});

test("crash detection reports only busy children that died", () => {
	fixture((_root, metadata) => {
		const terminal = { session: "s", window: "w", block: "b" };
		const busy = { ...metadata, state: "busy" as const, terminal };
		assert.equal(isCrashed(busy, "exited"), true);
		assert.equal(isCrashed({ ...busy, state: "starting" }, "exited"), true);
		assert.equal(isCrashed(busy, "running"), false);
		assert.equal(isCrashed(busy, "unknown"), false);
		assert.equal(isCrashed({ ...busy, state: "idle" }, "exited"), false);
		assert.equal(isCrashed({ ...busy, state: "exited" }, "exited"), false);
		assert.equal(isCrashed({ ...busy, suspended: true }, "exited"), false);
		assert.equal(isCrashed({ ...busy, terminal: undefined }, "exited"), false);
		assert.equal(isCrashed({ ...busy, notify: false }, "exited"), false);
		stoppingRuns.add(busy.handle);
		try {
			assert.equal(isCrashed(busy, "exited"), false);
		} finally {
			stoppingRuns.delete(busy.handle);
		}
		assert.equal(existsSync(eventsDir("parent")), false);
	});
});
