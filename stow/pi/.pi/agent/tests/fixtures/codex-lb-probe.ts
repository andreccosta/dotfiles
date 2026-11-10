// Loaded explicitly by the opt-in live test, never by normal extension discovery.
import { randomBytes } from "node:crypto";
import { Type } from "typebox";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { loadOpenAICodexLbAdapter } from "../../extensions/openai-codex-lb/clone.ts";

export default function (pi: ExtensionAPI) {
	let expected = randomBytes(12).toString("hex");
	let calls = 0;
	let payloads = 0;
	pi.on("before_provider_request", () => {
		payloads += 1;
	});
	pi.on("before_agent_start", (event) => {
		event.systemPromptOptions.forceSystemPrompt = `This is a diagnostic. Call diagnostic_echo with token ${expected}. After its first result, call diagnostic_echo again with the returned token. After its second result, reply with exactly the returned token and nothing else. Never invent a token. No other tools are needed.`;
	});
	pi.registerTool({
		name: "diagnostic_echo", label: "Diagnostic", description: "Validate a token and return the next diagnostic token",
		parameters: Type.Object({ token: Type.String() }),
		async execute(_id, { token }, _signal, _onUpdate, ctx) {
			if (calls >= 2 || token !== expected) throw new Error("Diagnostic instruction/tool replay check failed");
			calls += 1;
			expected = randomBytes(12).toString("hex");
			if (calls === 1 && process.env.CODEX_LB_PROBE_RECONNECT === "1") {
				(await loadOpenAICodexLbAdapter()).closeOpenAICodexWebSocketSessions(ctx.sessionManager.getSessionId());
			}
			return { content: [{ type: "text", text: expected }], details: { call: calls } };
		},
	});
	pi.on("agent_end", async (_event, ctx) => {
		const stats = process.env.CODEX_LB_TRANSPORT === "codex"
			? (await loadOpenAICodexLbAdapter()).getOpenAICodexWebSocketDebugStats(ctx.sessionManager.getSessionId())
			: undefined;
		console.error(`CODEX_LB_PROBE ${JSON.stringify({ calls, expected, payloads, stats })}`);
	});
}
