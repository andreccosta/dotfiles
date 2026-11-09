import assert from "node:assert/strict";
import { test } from "node:test";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import extension from "../extensions/openai-fast-aliases.ts";

test("fast aliases preserve priority tier with both work APIs", () => {
	let hook: Function | undefined;
	extension({ on: (_event: string, handler: Function) => { hook = handler; } } as unknown as ExtensionAPI);
	assert.ok(hook);
	for (const api of ["openai-responses", "work-codex-responses"]) {
		assert.deepEqual(hook({ payload: { model: "gpt-6.1-sol-fast", instructions: "keep", tools: ["keep"] } }, {
			model: { provider: "work", api, id: "gpt-6.1-sol-fast" },
		}), { model: "gpt-6.1-sol", service_tier: "priority", instructions: "keep", tools: ["keep"] });
	}
	assert.equal(hook({ payload: {} }, { model: { provider: "unrelated", api: "openai-responses", id: "gpt-6.1-sol-fast" } }), undefined);
});
