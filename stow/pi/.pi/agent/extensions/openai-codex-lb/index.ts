import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { loadOpenAICodexLbAdapter } from "./clone.ts";
import { loadOpenAICodexModels } from "./models.ts";

export const PROVIDER_ID = "work";
export const API_ID = "openai-responses";
export const CODEX_API_ID = "work-codex-responses";
export type LbTransport = "responses" | "codex";

export function resolveTransport(environment: NodeJS.ProcessEnv = process.env): LbTransport {
	const transport = environment.CODEX_LB_TRANSPORT ?? "codex";
	if (transport !== "responses" && transport !== "codex") {
		throw new Error("CODEX_LB_TRANSPORT must be responses or codex");
	}
	return transport;
}

const API_KEY_ENV = "CODEX_LB_API_KEY";
const BASE_URL_ENV = "CODEX_LB_URL";
const LEGACY_BASE_URL_ENV = "CODEX_LB_BASE_URL";
const DEFAULT_BASE_URL = "http://localhost:2455/v1";

function isCodexLbApiKey(value: unknown): value is string {
	return typeof value === "string" && value.startsWith("sk-clb-") && value.length > "sk-clb-".length;
}

export function resolveApiKeyConfig(environment: NodeJS.ProcessEnv = process.env): string {
	const environmentKey = environment[API_KEY_ENV]?.trim();
	if (!environmentKey) {
		throw new Error(`${API_KEY_ENV} is required`);
	}
	if (!isCodexLbApiKey(environmentKey)) {
		throw new Error(`${API_KEY_ENV} must contain a codex-lb API key`);
	}
	return `$${API_KEY_ENV}`;
}

export function normalizeBaseUrl(value: string, transport: LbTransport = "responses"): string {
	const url = new URL(value);
	if (url.protocol !== "http:" && url.protocol !== "https:") {
		throw new Error(`${BASE_URL_ENV} must use http or https`);
	}

	url.search = "";
	url.hash = "";
	url.pathname = url.pathname.replace(/\/+$/, "");
	if (transport === "codex") {
		if (!["/v1", "/backend-api", "/backend-api/codex", "/backend-api/codex/responses"].includes(url.pathname)) {
			throw new Error(`${BASE_URL_ENV} (or ${LEGACY_BASE_URL_ENV}) must target /v1 or the /backend-api Codex route`);
		}
		// Reuse the same server setting when switching transport. The adapter appends /codex/responses.
		url.pathname = "/backend-api";
	} else if (url.pathname !== "/v1") {
		throw new Error(`${BASE_URL_ENV} (or ${LEGACY_BASE_URL_ENV}) must target codex-lb's /v1 API route`);
	}

	return url.toString().replace(/\/+$/, "");
}

/** Codex is the default; standard Responses remains an explicit fallback. */
export default async function openAICodexLbExtension(pi: ExtensionAPI) {
	if (process.env[API_KEY_ENV] === undefined) return;

	const transport = resolveTransport();
	const configuredBaseUrl =
		process.env[BASE_URL_ENV] ?? process.env[LEGACY_BASE_URL_ENV] ?? DEFAULT_BASE_URL;

	const baseUrl = normalizeBaseUrl(configuredBaseUrl, transport);
	const apiKey = resolveApiKeyConfig();
	const models = loadOpenAICodexModels();
	const adapter = transport === "codex" ? await loadOpenAICodexLbAdapter() : undefined;

	pi.registerProvider(PROVIDER_ID, {
		name: "Work (OpenAI Codex LB)",
		baseUrl,
		apiKey,
		api: adapter ? CODEX_API_ID : API_ID,
		models,
		...(adapter ? { streamSimple: adapter.streamSimple } : {}),
	});

	if (adapter) {
		pi.on("session_shutdown", () => {
			adapter.closeOpenAICodexWebSocketSessions();
			adapter.resetOpenAICodexWebSocketDebugStats();
		});
	}
}
