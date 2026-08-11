import { readFileSync } from "node:fs";
import { join } from "node:path";
import { getAgentDir, type ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { loadOpenAICodexLbAdapter, resolveCodexAdapterUrl } from "./clone.ts";

export const PROVIDER_ID = "work";
export const API_ID = "work-codex-lb-responses";

const API_KEY_ENV = "CODEX_LB_API_KEY";
const BASE_URL_ENV = "CODEX_LB_URL";
const LEGACY_BASE_URL_ENV = "CODEX_LB_BASE_URL";
const DEFAULT_BASE_URL = "http://localhost:2455/backend-api";
const FALLBACK_AUTH_PROVIDERS = [PROVIDER_ID, "openai"] as const;

function isRecord(value: unknown): value is Record<string, unknown> {
	return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isCodexLbApiKey(value: unknown): value is string {
	return typeof value === "string" && value.startsWith("sk-clb-") && value.length > "sk-clb-".length;
}

export function findCodexLbApiKey(authFile: unknown): string | undefined {
	if (!isRecord(authFile)) return undefined;
	for (const provider of FALLBACK_AUTH_PROVIDERS) {
		const credential = authFile[provider];
		if (isRecord(credential) && credential.type === "api_key" && isCodexLbApiKey(credential.key)) {
			return credential.key;
		}
	}
	return undefined;
}

function readFallbackApiKey(agentDir: string): string | undefined {
	try {
		const authFile: unknown = JSON.parse(readFileSync(join(agentDir, "auth.json"), "utf8"));
		return findCodexLbApiKey(authFile);
	} catch {
		return undefined;
	}
}

export function resolveApiKeyConfig(agentDir: string, environment: NodeJS.ProcessEnv = process.env): string {
	const environmentKey = environment[API_KEY_ENV];
	if (environmentKey !== undefined && environmentKey.trim().length > 0) {
		if (!isCodexLbApiKey(environmentKey.trim())) {
			throw new Error(`${API_KEY_ENV} must contain a codex-lb API key`);
		}
		return `$${API_KEY_ENV}`;
	}

	return readFallbackApiKey(agentDir) ?? `$${API_KEY_ENV}`;
}

export function normalizeBaseUrl(value: string): string {
	const url = new URL(value);
	if (url.protocol !== "http:" && url.protocol !== "https:") {
		throw new Error(`${BASE_URL_ENV} must use http or https`);
	}

	url.search = "";
	url.hash = "";
	url.pathname = url.pathname.replace(/\/+$/, "");
	if (url.pathname === "/v1") url.pathname = "/backend-api";
	if (
		!url.pathname.endsWith("/backend-api") &&
		!url.pathname.endsWith("/backend-api/codex") &&
		!url.pathname.endsWith("/backend-api/codex/responses")
	) {
		throw new Error(
			`${BASE_URL_ENV} (or ${LEGACY_BASE_URL_ENV}) must target codex-lb's /v1 or /backend-api Codex route`,
		);
	}

	return url.toString().replace(/\/+$/, "");
}

/** Registers an isolated Codex adapter backed by codex-lb's API-key-authenticated Codex route. */
export default async function openAICodexLbExtension(pi: ExtensionAPI) {
	const adapterUrl = resolveCodexAdapterUrl();
	const adapter = await loadOpenAICodexLbAdapter({ sourceUrl: adapterUrl });
	const configuredBaseUrl =
		process.env[BASE_URL_ENV] ?? process.env[LEGACY_BASE_URL_ENV] ?? DEFAULT_BASE_URL;
	const baseUrl = normalizeBaseUrl(configuredBaseUrl);

	pi.registerProvider(PROVIDER_ID, {
		name: "Work (OpenAI Codex LB)",
		baseUrl,
		apiKey: resolveApiKeyConfig(getAgentDir()),
		api: API_ID,
		streamSimple: adapter.streamSimple,
	});

	pi.on("session_shutdown", () => {
		adapter.closeOpenAICodexWebSocketSessions();
		adapter.resetOpenAICodexWebSocketDebugStats();
	});
}
