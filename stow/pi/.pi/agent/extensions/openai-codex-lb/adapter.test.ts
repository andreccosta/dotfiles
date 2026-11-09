import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { createServer } from "node:http";
import { test } from "node:test";
import { normalizeContext } from "@earendil-works/pi-ai";
import type { Model, Api } from "@earendil-works/pi-ai";
import { absolutizeRelativeImports, loadOpenAICodexLbAdapter, resolveCodexAdapterUrl } from "./clone.ts";
import { CODEX_LB_PATCH_MARKER, patchOpenAICodexAdapter } from "./patch.ts";

const testModel: Model<Api> = {
	id: "gpt-6.1-sol", name: "Test", provider: "work", api: "work-codex-responses",
	baseUrl: "http://127.0.0.1/backend-api", reasoning: true, input: ["text"],
	cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
	contextWindow: 272000, maxTokens: 4096,
};

test("clones the installed Codex adapter without changing the original", async () => {
	const sourceUrl = resolveCodexAdapterUrl();
	const source = readFileSync(sourceUrl, "utf8");
	const patched = patchOpenAICodexAdapter(source);
	assert.match(patched, /const accountId = undefined;/);
	assert.match(patched, /"openai-codex", "work",/);
	assert.match(patched, /api: model.api/);
	assert.throws(() => patchOpenAICodexAdapter(source.replace("const accountId = extractAccountId(apiKey);", "")), /expected one source match, found 0/);
	assert.throws(() => patchOpenAICodexAdapter(source + "\n" + source), /expected one source match, found 2/);
	const original = await import(sourceUrl.href);
	const clone = await loadOpenAICodexLbAdapter({ sourceUrl });
	assert.equal(original[CODEX_LB_PATCH_MARKER], undefined);
	assert.notEqual(original.streamSimple, clone.streamSimple);
	assert.equal(readFileSync(sourceUrl, "utf8"), source);
	clone.closeOpenAICodexWebSocketSessions();
	clone.closeOpenAICodexWebSocketSessions();
	clone.resetOpenAICodexWebSocketDebugStats();
});

test("resolves relative imports for a data URL and rejects unresolved imports", () => {
	const transformed = absolutizeRelativeImports('import { x } from "./one.js"; import "../two.js"; const y = import("./three.js");', new URL("file:///tmp/api/adapter.js"));
	assert.match(transformed, /file:\/\/\/tmp\/api\/one.js/);
	assert.match(transformed, /file:\/\/\/tmp\/two.js/);
	assert.match(transformed, /file:\/\/\/tmp\/api\/three.js/);
	assert.throws(() => absolutizeRelativeImports("export const x = 1;", new URL("file:///tmp/a.js")), /not fully resolved/);
});

test("sends the LB bearer key without a ChatGPT account header and preserves instrumentation", { timeout: 10000 }, async () => {
	let captured: { url?: string; authorization?: string; account?: string | string[] } | undefined;
	const server = createServer((request, response) => {
		captured = { url: request.url, authorization: request.headers.authorization, account: request.headers["chatgpt-account-id"] };
		request.resume();
		response.writeHead(401, { "content-type": "application/json" });
		response.end(JSON.stringify({ error: { message: "expected test rejection" } }));
	});
	await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));
	const address = server.address();
	assert.ok(address && typeof address !== "string");
	let payloadSeen = false;
	let responseSeen = false;
	try {
		const adapter = await loadOpenAICodexLbAdapter();
		const stream = adapter.streamSimple({ ...testModel, baseUrl: `http://127.0.0.1:${address.port}/backend-api` }, normalizeContext({
			systemPrompt: "Preserve instructions", messages: [{ role: "user", content: "hello", timestamp: Date.now() }],
			tools: [{ name: "diagnostic_echo", description: "Echo", parameters: { type: "object", properties: {} } }],
		}), {
			apiKey: "sk-clb-test-key", maxRetries: 0, transport: "sse",
			onPayload: (payload) => {
				payloadSeen = true;
				assert.equal((payload as { instructions: string }).instructions, "Preserve instructions");
				assert.equal((payload as { tools: unknown[] }).tools.length, 1);
			},
			onResponse: (response) => { responseSeen = response.status === 401; },
		});
		const result = await stream.result();
		assert.equal(result.api, testModel.api);
		assert.equal(result.stopReason, "error");
		assert.deepEqual(captured, { url: "/backend-api/codex/responses", authorization: "Bearer sk-clb-test-key", account: undefined });
		assert.ok(payloadSeen);
		assert.ok(responseSeen);
	} finally {
		await new Promise<void>((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
	}
});
