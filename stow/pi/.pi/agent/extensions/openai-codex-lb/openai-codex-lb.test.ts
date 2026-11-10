import assert from "node:assert/strict";
import { test } from "node:test";
import type { ExtensionAPI, ProviderConfig } from "@earendil-works/pi-coding-agent";
import extension, { API_ID, CODEX_API_ID, normalizeBaseUrl, resolveApiKeyConfig, resolveTransport } from "./index.ts";

test("uses the standard Responses API", () => {
	assert.equal(API_ID, "openai-responses");
});

test("requires an explicit codex-lb environment key", () => {
	assert.equal(resolveApiKeyConfig({ CODEX_LB_API_KEY: "sk-clb-from-env" }), "$CODEX_LB_API_KEY");
	for (const value of [undefined, "", " \t\n"]) {
		assert.throws(() => resolveApiKeyConfig({ CODEX_LB_API_KEY: value }), /CODEX_LB_API_KEY is required/);
	}
	assert.throws(() => resolveApiKeyConfig({ OPENAI_API_KEY: "sk-openai" }), /CODEX_LB_API_KEY is required/);
});

test("accepts only the codex-lb v1 API route", () => {
	assert.equal(normalizeBaseUrl("http://codexlb.example:2455/v1/"), "http://codexlb.example:2455/v1");
	assert.throws(() => normalizeBaseUrl("http://codexlb.example:2455/backend-api"), /\/v1 API route/);
	assert.throws(() => normalizeBaseUrl("file:///tmp/v1"), /must use http or https/);
});

test("Codex transport is the default, Responses is opt-in, and invalid modes fail visibly", () => {
	assert.equal(resolveTransport({}), "codex");
	assert.equal(resolveTransport({ CODEX_LB_TRANSPORT: "responses" }), "responses");
	assert.equal(resolveTransport({ CODEX_LB_TRANSPORT: "codex" }), "codex");
	assert.throws(() => resolveTransport({ CODEX_LB_TRANSPORT: "websocket" }), /must be responses or codex/);
	assert.notEqual(CODEX_API_ID, API_ID);
});

test("Codex mode reuses the same server setting and canonicalizes supported routes", () => {
	for (const path of ["/v1", "/backend-api", "/backend-api/codex", "/backend-api/codex/responses/"]) {
		assert.equal(normalizeBaseUrl(`https://codexlb.example:2455${path}?ignored=yes#hash`, "codex"), "https://codexlb.example:2455/backend-api");
	}
	assert.throws(() => normalizeBaseUrl("https://codexlb.example/wrong", "codex"), /must target/);
	assert.throws(() => normalizeBaseUrl("file:///backend-api", "codex"), /must use http or https/);
});

test("rejects ordinary OpenAI keys and empty LB key prefixes", () => {
	for (const key of ["sk-openai", "sk-clb-"]) {
		assert.throws(() => resolveApiKeyConfig({ CODEX_LB_API_KEY: key }), /must contain a codex-lb API key/);
	}
});

test("registers work with catalog models, URL precedence, and Codex-only idempotent cleanup", async () => {
	const names = ["CODEX_LB_URL", "CODEX_LB_BASE_URL", "CODEX_LB_API_KEY", "CODEX_LB_TRANSPORT"];
	const saved = Object.fromEntries(names.map((name) => [name, process.env[name]]));
	try {
		process.env.CODEX_LB_API_KEY = "sk-clb-test";
		process.env.CODEX_LB_BASE_URL = "http://fallback.example:2455/v1";
		for (const transport of ["responses", "codex"] as const) {
			process.env.CODEX_LB_TRANSPORT = transport;
			process.env.CODEX_LB_URL = "http://primary.example:2455/v1";
			let registration: ProviderConfig | undefined;
			let cleanup: (() => void) | undefined;
			await extension({
				registerProvider: (id: string, config: ProviderConfig) => { assert.equal(id, "work"); registration = config; },
				on: (event: string, handler: () => void) => { assert.equal(event, "session_shutdown"); cleanup = handler; },
			} as unknown as ExtensionAPI);
			assert.ok(registration);
			assert.ok(registration.models && registration.models.length > 0);
			assert.equal(registration.apiKey, "$CODEX_LB_API_KEY");
			assert.equal(registration.api, transport === "codex" ? CODEX_API_ID : API_ID);
			assert.equal(registration.baseUrl, `http://primary.example:2455/${transport === "codex" ? "backend-api" : "v1"}`);
			assert.equal(typeof registration.streamSimple, transport === "codex" ? "function" : "undefined");
			assert.equal(typeof cleanup, transport === "codex" ? "function" : "undefined");
			cleanup?.();
			cleanup?.();
		}
		delete process.env.CODEX_LB_URL;
		process.env.CODEX_LB_TRANSPORT = "responses";
		await extension({ registerProvider: (_id: string, config: ProviderConfig) => {
			assert.equal(config.baseUrl, "http://fallback.example:2455/v1");
		} } as unknown as ExtensionAPI);
		delete process.env.CODEX_LB_API_KEY;
		await extension({
			registerProvider: () => assert.fail("must not register work without an environment key"),
			on: () => assert.fail("must not register handlers without an environment key"),
		} as unknown as ExtensionAPI);
	} finally {
		for (const name of names) {
			if (saved[name] === undefined) delete process.env[name];
			else process.env[name] = saved[name];
		}
	}
});
