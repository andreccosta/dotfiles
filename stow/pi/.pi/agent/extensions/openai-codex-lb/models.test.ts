import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import test from "node:test";
import { InMemoryModelsStore, type Model } from "@earendil-works/pi-ai";
import { OPENAI_CODEX_MODELS } from "@earendil-works/pi-ai/providers/openai-codex.models";
import { ModelRuntime } from "@earendil-works/pi-coding-agent";
import { loadOpenAICodexModels, prepareCodexModels } from "./models.ts";

const configPath = fileURLToPath(new URL("../../models.json", import.meta.url));
const config = JSON.parse(readFileSync(configPath, "utf8"));
const fastIds = [
	"gpt-5.5", "gpt-5.6-sol", "gpt-6.1-terra", "gpt-6.1-sol", "gpt-6-sol", "gpt-6-astra",
];

function fixture(id = "gpt-future"): Model<"openai-codex-responses"> {
	return {
		type: "chat",
		id,
		name: "Future GPT",
		api: "openai-codex-responses",
		provider: "openai-codex",
		baseUrl: "https://chatgpt.com/backend-api",
		reasoning: true,
		thinkingLevelMap: { minimal: "low", xhigh: "xhigh", max: "max" },
		input: ["text", "image"],
		cost: {
			input: 2, output: 10, cacheRead: 0.2, cacheWrite: 2.5,
			tiers: [{ inputTokensAbove: 272000, input: 4, output: 15, cacheRead: 0.4, cacheWrite: 5 }],
		},
		contextWindow: 500000,
		maxTokens: 128000,
		headers: { "X-Model": "test" },
		inputLimits: { images: { resize: { maxWidth: 2000 } } },
		promptCache: { short: 300 },
		compat: {
			supportsAdditionalTools: true,
			supportsMidConvoSystemMessages: true,
			supportsOpenAIGrammarTools: true,
			supportsToolSearch: true,
		},
		samplingParams: { temperature: 0.5 },
		samplingParamsByThinkingLevel: { high: { temperature: 0.3 } },
	};
}

test("loads every public upstream model synchronously without transport fields", () => {
	const models = loadOpenAICodexModels();
	assert.ok(Array.isArray(models));
	assert.equal(new Set(models.map((model) => model.id)).size, models.length);
	for (const upstream of Object.values(OPENAI_CODEX_MODELS)) {
		const { api: _api, provider: _provider, baseUrl: _baseUrl, compat: _compat, ...metadata } = upstream;
		assert.deepEqual(models.find((model) => model.id === upstream.id), metadata);
	}
	for (const model of models) {
		for (const key of ["api", "provider", "baseUrl", "compat"]) assert.equal(key in model, false);
	}
	assert.equal(models.some((model) => model.id === "gpt-reserve"), false);
});

test("future catalogs need neither Luna nor a reserve alias, and retain rich metadata", () => {
	const upstream = fixture();
	const models = prepareCodexModels({ [upstream.id]: upstream });
	const result = models.find((model) => model.id === upstream.id)!;
	const { api: _api, provider: _provider, baseUrl: _baseUrl, compat: _compat, ...metadata } = upstream;
	assert.deepEqual(result, metadata);
	assert.equal(models.some((model) => model.id === "gpt-reserve"), false);
	assert.equal(models.some((model) => model.id === "gpt-5.6-sol-fast"), false);
	assert.notEqual(result.cost, upstream.cost);
	assert.notEqual(result.cost.tiers, upstream.cost.tiers);
	assert.notEqual(result.inputLimits, upstream.inputLimits);
	assert.notEqual(result.headers, upstream.headers);
});

test("does not inherit unverified upstream wire capabilities, including on fast aliases", () => {
	const upstream = fixture("gpt-6-sol");
	const models = prepareCodexModels({ [upstream.id]: upstream });
	assert.ok(upstream.compat?.supportsAdditionalTools);
	assert.ok(upstream.compat?.supportsMidConvoSystemMessages);
	assert.ok(models.some((model) => model.id === "gpt-6-sol-fast"));
	for (const model of models) assert.equal("compat" in model, false);
	assert.equal(upstream.compat?.supportsAdditionalTools, true, "does not mutate upstream capabilities");
});

test("keeps GPT-5.5 as a local fallback but prefers upstream when present", () => {
	assert.ok(prepareCodexModels({ future: fixture() }).some((model) => model.id === "gpt-5.5"));
	const upstream = fixture("gpt-5.5");
	const models = prepareCodexModels({ [upstream.id]: upstream });
	assert.equal(models.filter((model) => model.id === upstream.id).length, 1);
	assert.equal(models.find((model) => model.id === upstream.id)?.contextWindow, 500000);
	assert.equal(models.find((model) => model.id === "gpt-5.5-fast")?.contextWindow, 500000);
});

test("preserves all existing fast aliases as independent priority metadata copies", () => {
	const models = loadOpenAICodexModels();
	for (const id of fastIds) {
		const base = models.find((model) => model.id === id)!;
		const fast = models.find((model) => model.id === `${id}-fast`)!;
		assert.ok(base);
		assert.ok(fast);
		assert.equal(fast.name, `${base.name} (Fast)`);
		assert.equal(fast.contextWindow, base.contextWindow);
		assert.deepEqual(fast.cost, base.cost);
		assert.notEqual(fast.cost, base.cost);
		assert.deepEqual(fast.samplingParams, { ...base.samplingParams, model: id, service_tier: "priority" });
	}
	const first = models.find((model) => model.id === "gpt-5.5")!;
	first.cost.input = 999;
	assert.notEqual(loadOpenAICodexModels().find((model) => model.id === first.id)?.cost.input, 999);
});

test("upstream fast IDs are not duplicated or overwritten", () => {
	const base = fixture("gpt-6-sol");
	const fast = fixture("gpt-6-sol-fast");
	fast.name = "Upstream Fast";
	const models = prepareCodexModels({ [base.id]: base, [fast.id]: fast });
	assert.equal(models.filter((model) => model.id === fast.id).length, 1);
	assert.equal(models.find((model) => model.id === fast.id)?.name, fast.name);
});

test("rejects an empty catalog rather than silently registering only fallback models", () => {
	assert.throws(() => prepareCodexModels({}), /catalog is empty/);
});

test("models.json leaves work metadata and aliases to the extension", () => {
	assert.equal(config.providers.work, undefined);
});

for (const api of ["openai-responses", "work-codex-responses"]) {
	test(`Pi preserves upstream metadata and generated aliases for ${api}`, async () => {
		const runtime = await ModelRuntime.create({
			modelsPath: configPath,
			modelsStore: new InMemoryModelsStore(),
			refreshOnCreate: false,
			allowModelNetwork: false,
		});
		const baseUrl = api === "openai-responses" ? "http://localhost:2455/v1" : "http://localhost:2455/backend-api";
		runtime.registerProvider("work", {
			api,
			baseUrl,
			apiKey: "test-key",
			models: loadOpenAICodexModels(),
		});
		assert.equal(runtime.getError(), undefined);
		assert.equal(runtime.getModels("work").length, loadOpenAICodexModels().length);
		for (const expected of loadOpenAICodexModels()) {
			const model = runtime.getModel("work", expected.id)!;
			assert.ok(model, `missing model ${expected.id}`);
			assert.equal(model.api, api);
			assert.equal(model.baseUrl, baseUrl);
			assert.equal(model.compat, undefined);
			assert.equal(model.contextWindow, expected.contextWindow);
			assert.equal(model.maxTokens, expected.maxTokens);
			assert.deepEqual(model.cost, expected.cost);
			assert.deepEqual(model.thinkingLevelMap, expected.thinkingLevelMap);
			assert.deepEqual(model.samplingParams, expected.samplingParams);
		}
	});
}
