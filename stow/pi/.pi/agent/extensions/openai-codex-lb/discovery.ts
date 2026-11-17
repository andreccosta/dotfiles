import type { Model, ModelsStoreEntry, ModelThinkingLevel, RefreshModelsContext } from "@earendil-works/pi-ai";
import { loadOpenAICodexModels, type CodexLbModel } from "./models.ts";

const REFRESH_INTERVAL_MS = 5 * 60 * 1000;
const REQUEST_TIMEOUT_MS = 5000;
const LEVELS: ModelThinkingLevel[] = ["off", "minimal", "low", "medium", "high", "xhigh", "max"];

function record(value: unknown): Record<string, unknown> {
	return typeof value === "object" && value !== null && !Array.isArray(value) ? value as Record<string, unknown> : {};
}

function positive(value: unknown): number | undefined {
	return typeof value === "number" && Number.isSafeInteger(value) && value > 0 ? value : undefined;
}

/** LB availability is authoritative; Pi supplies metadata the LB omits. */
export function prepareDiscoveredModels(payload: unknown, fallback = loadOpenAICodexModels()): CodexLbModel[] {
	const data = record(payload).data;
	if (!Array.isArray(data)) throw new Error("Invalid codex-lb model catalog");
	const seen = new Set<string>();
	return data.map((entry) => {
		const model = record(entry);
		if (typeof model.id !== "string" || !model.id.trim() || seen.has(model.id)) {
			throw new Error("Invalid or duplicate codex-lb model ID");
		}
		seen.add(model.id);
		const metadata = record(model.metadata);
		const capabilities = record(model.capabilities);
		const upstream = fallback.find((candidate) => candidate.id === model.id);
		const contextWindow = positive(metadata.input_context_window) ?? positive(metadata.context_window)
			?? positive(capabilities.context_length) ?? positive(model.context_length) ?? upstream?.contextWindow ?? 128000;
		const maxTokens = Math.min(contextWindow, positive(metadata.max_output_tokens)
			?? positive(capabilities.max_output_tokens) ?? positive(model.max_output_tokens) ?? upstream?.maxTokens ?? 16384);
		const modalities = metadata.input_modalities ?? capabilities.input_modalities;
		const input: CodexLbModel["input"] = Array.isArray(modalities)
			? modalities.filter((value): value is "text" | "image" => value === "text" || value === "image")
			: upstream?.input ?? ["text"];
		if (!input.includes("text")) throw new Error("Unsupported codex-lb input modalities");
		const efforts = Array.isArray(metadata.supported_reasoning_levels)
			? metadata.supported_reasoning_levels.map((level) => record(level).effort) : undefined;
		const thinkingLevelMap = efforts
			? Object.fromEntries(LEVELS.map((level) => [level,
				level === "off" && efforts.includes("none") ? "none" : efforts.includes(level) ? level : null,
			]))
			: upstream?.thinkingLevelMap;
		return {
			// Never copy LB wire flags, headers, or API declarations into Pi's transport.
			type: "chat",
			id: model.id,
			name: typeof metadata.display_name === "string" ? metadata.display_name : upstream?.name ?? model.id,
			contextWindow,
			maxTokens,
			input,
			reasoning: typeof capabilities.supports_reasoning === "boolean" ? capabilities.supports_reasoning
				: efforts ? efforts.length > 0 : upstream?.reasoning ?? false,
			thinkingLevelMap,
			cost: structuredClone(upstream?.cost ?? { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 }),
			...(upstream?.inputLimits ? { inputLimits: structuredClone(upstream.inputLimits) } : {}),
		};
	});
}

export function createModelDiscovery(options: {
	baseUrl: string;
	api: string;
	apiKey: () => string;
	fetch?: typeof fetch;
}) {
	const fetchModels = options.fetch ?? fetch;
	const url = new URL(options.baseUrl);
	url.pathname = "/v1/models";
	let models = loadOpenAICodexModels();
	let checkedAt = 0;
	let pendingPersistence = false;

	// Model entries cannot carry endpoint identity when the catalog is empty.
	// Pi's model store preserves this provider-owned metadata with the snapshot.
	type CatalogEntry = ModelsStoreEntry & { codexLb: { baseUrl: string; api: string } };
	const catalogEntry = (catalog: CodexLbModel[], timestamp: number): CatalogEntry => ({
		models: catalog.map((model): Model<string> => ({
			...model, provider: "work", api: options.api, baseUrl: options.baseUrl,
		})),
		checkedAt: timestamp,
		codexLb: { baseUrl: options.baseUrl, api: options.api },
	});
	async function discover(signal?: AbortSignal) {
		const timeout = AbortSignal.timeout(REQUEST_TIMEOUT_MS);
		const response = await fetchModels(url, {
			headers: { Authorization: `Bearer ${options.apiKey()}`, Accept: "application/json" },
			signal: signal ? AbortSignal.any([signal, timeout]) : timeout,
			redirect: "error",
		});
		if (!response.ok) throw new Error(`codex-lb model discovery failed: HTTP ${response.status}`);
		const discovered = prepareDiscoveredModels(await response.json());
		signal?.throwIfAborted();
		return discovered;
	}

	return {
		get models() { return models; },
		/** Async factory discovery also makes new models visible to --list-models. */
		async initialize() {
			try {
				models = await discover();
				checkedAt = Date.now();
				pendingPersistence = true;
			} catch {
				// Pi restores the persisted catalog during its cache-only refresh phase.
			}
		},
		async refreshModels(context: RefreshModelsContext): Promise<CodexLbModel[]> {
			context.signal.throwIfAborted();
			const stored = context.stored;
			const identity = record(record(stored).codexLb);
			const matchesIdentity = identity.baseUrl === options.baseUrl && identity.api === options.api;
			// Nonempty legacy snapshots still encode their identity in every model.
			const matchesModels = stored?.models.every((model) => model.provider === "work"
				&& model.baseUrl === options.baseUrl && model.api === options.api);
			const cached = matchesModels && (matchesIdentity || (stored?.models.length && !record(stored).codexLb))
				? stored?.models : undefined;
			if (cached !== undefined && (stored?.checkedAt ?? 0) > checkedAt) {
				models = cached.map(({ api: _api, provider: _provider, baseUrl: _baseUrl, compat: _compat, headers: _headers, ...metadata }) => structuredClone(metadata));
				checkedAt = stored?.checkedAt ?? 0;
				pendingPersistence = false;
			}
			if (context.allowNetwork && (context.force || Date.now() - checkedAt >= REFRESH_INTERVAL_MS)) {
				try {
					const discovered = await discover(context.signal);
					const entry = catalogEntry(discovered, Date.now());
					if (await context.publish({ persist: entry })) {
						models = discovered;
						checkedAt = entry.checkedAt;
						pendingPersistence = false;
					}
				} catch {
					context.signal.throwIfAborted();
					// Keep the last successful catalog on network/HTTP/schema failure.
				}
			}
			if (pendingPersistence && await context.publish({ persist: catalogEntry(models, checkedAt) })) {
				pendingPersistence = false;
			}
			return structuredClone(models);
		},
	};
}
