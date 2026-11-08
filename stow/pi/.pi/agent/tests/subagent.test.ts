import assert from "node:assert/strict";
import { test } from "node:test";
import { mkdtempSync, mkdirSync, readFileSync, readdirSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import extension from "../extensions/subagent/index.ts";
import { runSubagent, type ParentContext } from "../extensions/subagent/operations.ts";
import { inboxDir, updateMetadata } from "../extensions/subagent/shared.ts";

// A fake Rex executable exercises process integration without touching live Rex.
test("subagent tool lifecycle", async (t) => {
	const root = mkdtempSync(join(tmpdir(), "pi-subagent-test-"));
	const previous = { PATH: process.env.PATH, PI_CODING_AGENT_DIR: process.env.PI_CODING_AGENT_DIR, PI_SUBAGENT_RUN_DIR: process.env.PI_SUBAGENT_RUN_DIR };
	const bin = join(root, "bin");
	mkdirSync(bin);
	writeFileSync(join(bin, "rex"), `#!${process.execPath}
const fs = require('node:fs');
const path = require('node:path');
const marker = path.join(process.env.PI_CODING_AGENT_DIR, 'stopped');
const args = process.argv.slice(2);
if (args[0] === 'new') console.log(JSON.stringify({ session_id: 'session', initial_windows: [{window_id:'window',block_ids:['block']}] }));
else if (args[0] === 'api') console.log(JSON.stringify(fs.existsSync(marker) ? {} : {child:{pid:123}}));
else if (args[0] === 'window' && args[1] === 'close') fs.writeFileSync(marker, 'yes');
else if (args[0] === 'window' && args[1] === 'ls') console.log(JSON.stringify({ windows: [] }));
`, { mode: 0o755 });
	process.env.PATH = `${bin}:${previous.PATH}`;
	process.env.PI_CODING_AGENT_DIR = root;
	delete process.env.PI_SUBAGENT_RUN_DIR;
	t.after(() => {
		for (const [key, value] of Object.entries(previous)) {
			if (value === undefined) delete process.env[key]; else process.env[key] = value;
		}
		rmSync(root, { recursive: true, force: true });
	});
	const parent: ParentContext = { sessionId: "parent", sessionFile: join(root, "parent.jsonl"), cwd: root, provider: "work", model: "test-model", thinking: "high" };

	let registeredTool: any;
	await t.test("registers tool and skill only in parent", () => {
		const tools: any[] = [];
		const events = new Map();
		extension({ registerTool: (tool: any) => tools.push(tool), on: (event: string, handler: any) => events.set(event, handler) } as any);
		assert.equal(tools[0].name, "subagent");
		registeredTool = tools[0];
		assert.ok(events.get("resources_discover")().skillPaths[0].endsWith("/skills"));
		process.env.PI_SUBAGENT_RUN_DIR = join(root, "child");
		const childTools: any[] = [];
		extension({ registerTool: (tool: any) => childTools.push(tool), on() {} } as any);
		assert.equal(childTools.length, 0);
		delete process.env.PI_SUBAGENT_RUN_DIR;
	});

	await t.test("validates spawn before creating a run", async () => {
		await assert.rejects(runSubagent({ action: "spawn" }, parent), /requires prompts or files/);
		await assert.rejects(runSubagent({ action: "spawn", prompts: ["task"], tools: [] }, parent), /Tools/);
		await assert.rejects(runSubagent({ action: "spawn", prompts: ["task"], group: "x".repeat(25) }, parent), /Group/);
	});

	const spawned = await runSubagent({ action: "spawn", name: "review", group: "test task", prompts: ["Inspect tests"], noExtensions: true }, parent);
	const run = spawned.runs[0];
	const handle = run.handle;
	await t.test("inherits Pi context and loads child bridge", () => {
		assert.equal(run.provider, parent.provider);
		assert.equal(run.model, parent.model);
		assert.equal(run.thinking, "high");
		assert.equal(run.cwd, root);
		assert.equal(run.parentSessionId, "parent");
		assert.ok(run.launchArgs?.includes("--no-extensions"));
		assert.ok(run.launchArgs?.some((arg) => arg.endsWith("subagent/index.ts")));
		assert.equal(run.terminal?.block, "block");
	});

	await t.test("scopes list and handle operations to parent", async () => {
		assert.equal((await runSubagent({ action: "list" }, parent)).runs.length, 1);
		const other = { ...parent, sessionId: "other" };
		assert.equal((await runSubagent({ action: "list" }, other)).runs.length, 0);
		await assert.rejects(runSubagent({ action: "stop", handle }, other), /Unknown subagent/);
		await assert.rejects(runSubagent({ action: "status", handle: "../outside" }, parent), /valid subagent handle/);
	});

	await t.test("renames and queues literal messages without CLI parsing", async () => {
		const renamed = await runSubagent({ action: "rename", handle, name: "new name" }, parent);
		assert.equal(renamed.runs[0].name, "new name");
		await runSubagent({ action: "send", handle, message: "--follow-up is literal text", followUp: true }, parent);
		const queue = inboxDir(run.runDir);
		const file = readdirSync(queue)[0];
		assert.deepEqual(JSON.parse(readFileSync(join(queue, file), "utf8")), { message: "--follow-up is literal text", delivery: "followUp" });
		rmSync(join(queue, file));
	});

	await t.test("wait supports cancellation and validates timeout", async () => {
		await assert.rejects(runSubagent({ action: "wait", handle, timeoutSeconds: 0 }, parent), /positive integer/);
		const controller = new AbortController();
		const timer = setTimeout(() => controller.abort(), 100);
		try {
			await assert.rejects(runSubagent({ action: "wait", handle }, parent, controller.signal), { name: "AbortError" });
		} finally {
			clearTimeout(timer);
		}
		assert.equal((await runSubagent({ action: "status", handle }, parent)).runs.length, 1);
	});

	await t.test("wait reads final response and surfaces error stop reasons", async () => {
		const sessionFile = join(root, "child.jsonl");
		writeFileSync(sessionFile, JSON.stringify({ type: "message", id: "one", parentId: null, message: { role: "assistant", content: [{ type: "text", text: "Finished review" }], stopReason: "error" } }) + "\n");
		updateMetadata(run.runDir, { state: "idle", hasStarted: true, sessionFile });
		const response = await runSubagent({ action: "wait", handle }, parent);
		assert.equal(response.text, "Finished review");
		assert.equal(response.isError, true);
		writeFileSync(sessionFile, JSON.stringify({ type: "message", id: "one", parentId: null, message: { role: "assistant", content: [{ type: "text", text: "x".repeat(60_000) }], stopReason: "stop" } }) + "\n");
		const toolResult = await registeredTool.execute("test", { action: "wait", handle }, undefined, undefined, {
			sessionManager: { getSessionId: () => parent.sessionId, getSessionFile: () => parent.sessionFile },
			cwd: parent.cwd, model: { provider: parent.provider, id: parent.model }, thinkingLevel: parent.thinking,
		});
		assert.ok(toolResult.content[0].text.includes("Response truncated"));
		assert.ok(toolResult.content[0].text.length < 52_000);
		assert.equal(toolResult.details.runs[0].sessionFile, sessionFile);
		assert.equal(toolResult.isError, false);
		// Avoid the shutdown grace period in this fake-process test.
		writeFileSync(join(root, "stopped"), "yes");
		await runSubagent({ action: "stop", handle }, parent);
		assert.equal((await runSubagent({ action: "list" }, parent)).runs.length, 0);
		assert.equal(readFileSync(sessionFile, "utf8").includes("x".repeat(60_000)), true);
	});
});
