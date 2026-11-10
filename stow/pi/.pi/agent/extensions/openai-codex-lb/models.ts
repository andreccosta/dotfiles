import type { Model } from "@earendil-works/pi-ai";
import { getBuiltinModels } from "@earendil-works/pi-ai/providers/all";

/** Model metadata only: the registering provider owns the transport and endpoint. */
export type CodexLbModel = Omit<Model<"openai-codex-responses">, "api" | "provider" | "baseUrl" | "compat">;
type CodexCatalog = Readonly<Record<string, Model<"openai-codex-responses">>>;

// codex-lb still exposes this local model, but Pi's legacy Codex catalog no
// longer includes it. Prefer upstream metadata automatically if it reappears.
const GPT_55_FALLBACK: CodexLbModel = {
	id: "gpt-5.5",
	name: "GPT-5.5",
	reasoning: true,
	thinkingLevelMap: { off: "none", minimal: null, xhigh: "xhigh" },
	input: ["text", "image"],
	cost: { input: 5, output: 30, cacheRead: 0.5, cacheWrite: 0 },
	contextWindow: 272000,
	maxTokens: 128000,
};

/** Project a public upstream catalog; exported separately for offline tests. */
export function prepareCodexModels(catalog: CodexCatalog): CodexLbModel[] {
	const upstream = Object.values(catalog);
	if (upstream.length === 0) throw new Error("OpenAI Codex model catalog is empty");

	const models: CodexLbModel[] = upstream.map((model) => {
		// ChatGPT's transport and wire capabilities are not the LB's contract.
		// In particular, upstream compat flags opt into Responses Lite features
		// the LB rejects. Only enable capabilities separately after verification.
		// Keep catalog metadata such as cost tiers and image input limits.
		const { api: _api, provider: _provider, baseUrl: _baseUrl, compat: _compat, ...metadata } = model;
		return structuredClone(metadata);
	});
	if (!models.some((model) => model.id === GPT_55_FALLBACK.id)) {
		models.push(structuredClone(GPT_55_FALLBACK));
	}

	return models;
}

/**
 * Use Pi's supported catalog export, which its extension loader maps to the host
 * package. Importing individual provider subpaths is not supported by that map.
 * Local models.json modelOverrides are applied by Pi after registration.
 */
export function loadOpenAICodexModels(): CodexLbModel[] {
	const models = getBuiltinModels("openai-codex");
	return prepareCodexModels(Object.fromEntries(models.map((model) => [model.id, model])));
}
