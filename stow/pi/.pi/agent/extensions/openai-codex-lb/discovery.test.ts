import assert from "node:assert/strict";
import test from "node:test";
import { clampThinkingLevel, InMemoryModelsStore, type ModelsStoreEntry, type RefreshModelsContext } from "@earendil-works/pi-ai";
import { ModelRuntime } from "@earendil-works/pi-coding-agent";
import { createModelDiscovery, prepareDiscoveredModels } from "./discovery.ts";
import { loadOpenAICodexModels } from "./models.ts";

const baseUrl = "http://lb.example:2455/backend-api";
const api = "work-codex-responses";
const payload = { data: [{
	id: "gpt-6.2-sol",
	metadata: {
		display_name: "GPT-6.2-Sol", input_context_window: 500000,
		max_output_tokens: null, input_modalities: ["text", "image", "audio"],
		supported_reasoning_levels: [{ effort: "low" }, { effort: "medium" }, { effort: "high" }, { effort: "max" }, { effort: "ultra" }],
	},
	capabilities: { supports_reasoning: true },
	api: "wrong", compat: { supportsToolSearch: true }, headers: { Authorization: "do-not-copy" },
}] };

function context(stored?: ModelsStoreEntry, overrides: Partial<RefreshModelsContext> = {}) {
	const publications: ModelsStoreEntry[] = [];
	const ctx: RefreshModelsContext = {
		stored, allowNetwork: false, signal: new AbortController().signal,
		publish: async (publication) => {
			if (publication.persist) publications.push(publication.persist);
			publication.update?.();
			return true;
		},
		...overrides,
	};
	return { ctx, publications };
}

function discovery(fetch: typeof globalThis.fetch) {
	return createModelDiscovery({ baseUrl, api, apiKey: () => "sk-clb-test", fetch });
}

test("LB defines availability and capabilities, with safe defaults for new models", () => {
	const [model] = prepareDiscoveredModels(payload);
	assert.equal(model.id, "gpt-6.2-sol");
	assert.equal(model.name, "GPT-6.2-Sol");
	assert.equal(model.contextWindow, 500000);
	assert.equal(model.maxTokens, 16384);
	assert.deepEqual(model.input, ["text", "image"]);
	assert.equal(model.reasoning, true);
	assert.deepEqual(model.thinkingLevelMap, { off: null, minimal: null, low: "low", medium: "medium", high: "high", xhigh: null, max: "max" });
	assert.deepEqual(model.cost, { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 });
	for (const key of ["api", "compat", "headers", "provider", "baseUrl"]) assert.equal(key in model, false);
});

test("fills missing metadata by exact model ID without adding unadvertised models", () => {
	const upstream = loadOpenAICodexModels().find((model) => model.id === "gpt-6.1-sol")!;
	const [model] = prepareDiscoveredModels({ data: [{ id: upstream.id }] });
	assert.deepEqual(model.cost, upstream.cost);
	assert.equal(model.maxTokens, upstream.maxTokens);
	assert.equal(model.contextWindow, upstream.contextWindow);
	assert.notEqual(model.cost, upstream.cost);
	assert.equal(prepareDiscoveredModels({ data: [{ id: upstream.id }] }).length, 1);
	assert.equal(prepareDiscoveredModels({ data: [{ id: "new", context_length: 8192, max_output_tokens: 99999 }] })[0].maxTokens, 8192);
});

test("maps the none wire effort to Pi off without clamping it to low", () => {
	const [model] = prepareDiscoveredModels({ data: [{
		id: "gpt-5.5",
		metadata: { supported_reasoning_levels: [{ effort: "none" }, { effort: "low" }] },
	}] });
	assert.equal(model.thinkingLevelMap?.off, "none");
	assert.equal(model.thinkingLevelMap?.low, "low");
	assert.equal(model.thinkingLevelMap?.medium, null);
	assert.equal(clampThinkingLevel({ ...model, api, provider: "work", baseUrl }, "off"), "off");
});

test("rejects invalid and duplicate catalogs but accepts an authoritative empty list", () => {
	assert.deepEqual(prepareDiscoveredModels({ data: [] }), []);
	for (const value of [null, {}, { data: [null] }, { data: [{ id: "" }] }, { data: [{ id: "a" }, { id: "a" }] }]) {
		assert.throws(() => prepareDiscoveredModels(value), /catalog|model ID/);
	}
});

test("factory discovery authenticates to /v1/models and persists through Pi", async () => {
	let calls = 0;
	const source = discovery(async (url, init) => {
		calls++;
		assert.equal(String(url), "http://lb.example:2455/v1/models");
		assert.equal((init?.headers as Record<string, string>).Authorization, "Bearer sk-clb-test");
		assert.ok(init?.signal);
		assert.equal(init?.redirect, "error");
		return Response.json(payload);
	});
	await source.initialize();
	assert.deepEqual(source.models.map((model) => model.id), ["gpt-6.2-sol"]);
	const { ctx, publications } = context();
	await source.refreshModels(ctx);
	assert.equal(calls, 1);
	assert.equal(publications.length, 1);
	assert.equal(publications[0].models[0].baseUrl, baseUrl);
	assert.equal(publications[0].models[0].api, api);
	await source.refreshModels({ ...ctx, allowNetwork: true });
	assert.equal(calls, 1, "fresh discovery is not fetched again");
	await source.refreshModels({ ...ctx, allowNetwork: true, force: true });
	assert.equal(calls, 2);
});

test("restores persisted models offline and retains them on HTTP/schema/network failure", async () => {
	const cachedModels = prepareDiscoveredModels(payload).map((model) => ({ ...model, provider: "work", api, baseUrl }));
	const stored = { models: cachedModels, checkedAt: Date.now() - 600000 };
	for (const fetch of [
		async () => { throw new Error("offline"); },
		async () => new Response("unauthorized", { status: 401 }),
		async () => Response.json({ data: null }),
	]) {
		const source = discovery(fetch);
		await source.initialize();
		const { ctx, publications } = context(stored);
		assert.deepEqual((await source.refreshModels(ctx)).map((model) => model.id), ["gpt-6.2-sol"]);
		assert.deepEqual((await source.refreshModels({ ...ctx, allowNetwork: true })).map((model) => model.id), ["gpt-6.2-sol"]);
		assert.equal(publications.length, 0, "failed discovery must not overwrite the persisted catalog");
	}
});

test("does not restore catalogs from another endpoint or transport", async () => {
	for (const changes of [{ baseUrl: "http://other/v1" }, { api: "openai-responses" }]) {
		const source = discovery(async () => { throw new Error("offline"); });
		const stored = { checkedAt: Date.now(), models: prepareDiscoveredModels(payload).map((model) => ({ ...model, provider: "work", api, baseUrl, ...changes })) };
		const { ctx } = context(stored);
		const result = await source.refreshModels(ctx);
		assert.equal(result.some((model) => model.id === "gpt-6.2-sol"), false);
	}
});

test("an empty startup catalog is persisted and restored without a bundled fallback", async () => {
	const source = discovery(async () => Response.json({ data: [] }));
	await source.initialize();
	assert.deepEqual(source.models, []);
	const { ctx, publications } = context();
	assert.deepEqual(await source.refreshModels(ctx), []);
	assert.deepEqual(publications[0].models, []);
	const stored = JSON.parse(JSON.stringify(publications[0])) as ModelsStoreEntry;
	const offline = discovery(async () => { throw new Error("offline"); });
	await offline.initialize();
	const restored = context(stored);
	assert.deepEqual(await offline.refreshModels(restored.ctx), []);
	assert.deepEqual(await offline.refreshModels({ ...restored.ctx, allowNetwork: true, force: true }), []);
	assert.equal(restored.publications.length, 0);

	for (const changes of [{ baseUrl: "http://other/v1" }, { api: "openai-responses" }]) {
		const other = createModelDiscovery({ baseUrl, api, ...changes, apiKey: () => "key" });
		assert.deepEqual(await other.refreshModels(context(stored).ctx), loadOpenAICodexModels());
	}
});

test("honors cancellation and rejected generation publications", async () => {
	const source = discovery(async (_url, init) => {
		assert.ok(init?.signal);
		return Response.json(payload);
	});
	const { ctx } = context(undefined, { allowNetwork: true, publish: async () => false });
	assert.equal((await source.refreshModels(ctx)).some((model) => model.id === "gpt-6.2-sol"), false);
	const controller = new AbortController();
	controller.abort();
	await assert.rejects(source.refreshModels({ ...ctx, signal: controller.signal }), /abort/i);
});

test("in-flight cancellation reaches fetch without persisting a catalog", async () => {
	const controller = new AbortController();
	const source = discovery(async (_url, init) => {
		return new Promise<Response>((_resolve, reject) => {
			init!.signal!.addEventListener("abort", () => reject(init!.signal!.reason), { once: true });
			controller.abort();
		});
	});
	const { ctx, publications } = context(undefined, { allowNetwork: true, signal: controller.signal });
	await assert.rejects(source.refreshModels(ctx), /abort/i);
	assert.equal(publications.length, 0);
});

test("startup discovery timeout falls back without hanging", async (t) => {
	t.mock.method(AbortSignal, "timeout", (milliseconds: number) => {
		assert.equal(milliseconds, 5000);
		return AbortSignal.abort(new DOMException("Timed out", "TimeoutError"));
	});
	const source = discovery(async (_url, init) => {
		init!.signal!.throwIfAborted();
		assert.fail("timeout should have aborted fetch");
	});
	await source.initialize();
	assert.deepEqual(source.models, loadOpenAICodexModels());
});

test("Pi persists and restores discovery for both transports", async () => {
	for (const transportApi of ["openai-responses", api]) {
		for (const catalog of [payload, { data: [] }]) {
			const expectedIds = catalog.data.map((model) => model.id);
			const store = new InMemoryModelsStore();
			const source = createModelDiscovery({ baseUrl, api: transportApi, apiKey: () => "key", fetch: async () => Response.json(catalog) });
			const runtime = await ModelRuntime.create({ modelsStore: store, allowModelNetwork: false, refreshOnCreate: false });
			runtime.registerProvider("work", { baseUrl, api: transportApi, apiKey: "key", models: source.models, refreshModels: source.refreshModels });
			await runtime.refresh({ allowNetwork: true, providers: ["work"], force: true });
			assert.deepEqual(runtime.getModels("work").map((model) => model.id), expectedIds);
			assert.ok(await store.read("work"));
			const restored = await ModelRuntime.create({ modelsStore: store, allowModelNetwork: false, refreshOnCreate: false });
			const offline = createModelDiscovery({ baseUrl, api: transportApi, apiKey: () => "key", fetch: async () => { throw new Error("must not fetch"); } });
			restored.registerProvider("work", { baseUrl, api: transportApi, apiKey: "key", models: offline.models, refreshModels: offline.refreshModels });
			await restored.refresh({ allowNetwork: false, providers: ["work"] });
			assert.deepEqual(restored.getModels("work").map((model) => model.id), expectedIds);
			for (const model of restored.getModels("work")) {
				assert.equal(model.api, transportApi);
				assert.equal(model.compat, undefined);
			}
		}
	}
});
