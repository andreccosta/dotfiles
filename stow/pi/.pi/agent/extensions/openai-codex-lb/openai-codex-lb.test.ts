import assert from "node:assert/strict";
import { test } from "node:test";
import { API_ID, findCodexLbApiKey, normalizeBaseUrl, resolveApiKeyConfig } from "./index.ts";

test("uses the standard Responses API", () => {
	assert.equal(API_ID, "openai-responses");
});

test("resolves codex-lb API keys", () => {
	assert.equal(
		findCodexLbApiKey({ work: { type: "api_key", key: "sk-clb-work" } }),
		"sk-clb-work",
	);
	assert.equal(
		findCodexLbApiKey({ openai: { type: "api_key", key: "sk-clb-example" } }),
		"sk-clb-example",
	);
	assert.equal(findCodexLbApiKey({ openai: { type: "api_key", key: "sk-openai" } }), undefined);
	assert.equal(
		resolveApiKeyConfig("/path/that/does/not/exist", { CODEX_LB_API_KEY: "sk-clb-from-env" }),
		"$CODEX_LB_API_KEY",
	);
});

test("accepts only the codex-lb v1 API route", () => {
	assert.equal(normalizeBaseUrl("http://codexlb.example:2455/v1/"), "http://codexlb.example:2455/v1");
	assert.throws(() => normalizeBaseUrl("http://codexlb.example:2455/backend-api"), /\/v1 API route/);
	assert.throws(() => normalizeBaseUrl("file:///tmp/v1"), /must use http or https/);
});
