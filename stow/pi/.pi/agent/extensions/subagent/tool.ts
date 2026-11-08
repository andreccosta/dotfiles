import { type ExtensionAPI, truncateHead } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import { runSubagent } from "./operations.ts";

export function registerSubagentTool(pi: ExtensionAPI): void {
	pi.registerTool({
		name: "subagent",
		label: "Subagent",
		description: "Manage observable Pi child agents in Rex tabs: spawn, status, rename, send, wait, stop, or list. Inherits the parent model and reasoning level by default. Wait returns the latest assistant response (limited to 50KB/2000 lines); cancellation stops waiting, not the child. Stop children when finished.",
		promptSnippet: "Spawn and manage Pi subagents in Rex tabs for independent work",
		promptGuidelines: ["Use the subagent tool for Pi child agents; read its bundled skill for lifecycle and isolation guidance. Stop subagents when no longer needed."],
		parameters: Type.Object({
			action: Type.Union((["spawn", "status", "rename", "send", "wait", "stop", "list"] as const).map((value) => Type.Literal(value))),
			handle: Type.Optional(Type.String({ description: "Handle returned by spawn; required except for spawn/list" })),
			name: Type.Optional(Type.String({ description: "Child display name; required for rename" })),
			group: Type.Optional(Type.String({ maxLength: 24, description: "Short parent task label for the shared Rex session" })),
			provider: Type.Optional(Type.String()),
			model: Type.Optional(Type.String()),
			thinking: Type.Optional(Type.Union((["off", "minimal", "low", "medium", "high", "xhigh", "max"] as const).map((value) => Type.Literal(value)))),
			cwd: Type.Optional(Type.String()),
			tools: Type.Optional(Type.Array(Type.String(), { minItems: 1 })),
			prompts: Type.Optional(Type.Array(Type.String())),
			files: Type.Optional(Type.Array(Type.String())),
			noExtensions: Type.Optional(Type.Boolean()),
			noSkills: Type.Optional(Type.Boolean()),
			noPromptTemplates: Type.Optional(Type.Boolean()),
			noContextFiles: Type.Optional(Type.Boolean()),
			message: Type.Optional(Type.String({ description: "Required for send" })),
			followUp: Type.Optional(Type.Boolean()),
			timeoutSeconds: Type.Optional(Type.Integer({ minimum: 1, description: "Wait deadline; default 1800 seconds" })),
		}),
		async execute(_id, params, signal, _onUpdate, ctx) {
			const result = await runSubagent(params, {
				sessionId: ctx.sessionManager.getSessionId(),
				sessionFile: ctx.sessionManager.getSessionFile() ?? undefined,
				cwd: ctx.cwd,
				provider: ctx.model?.provider,
				model: ctx.model?.id,
				thinking: ctx.thinkingLevel,
			}, signal);
			const summary = result.runs.map((run) => `${run.name ?? run.handle} (${run.handle}): ${run.state} [${run.provider}/${run.model}, ${run.thinking}]`).join("\n") || "No subagents";
			const truncated = truncateHead([summary, result.text].filter(Boolean).join("\n\n"));
			const text = truncated.content + (truncated.truncated ? "\n[Response truncated. Full response is in the child's sessionFile transcript.]" : "");
			return {
				content: [{ type: "text", text }],
				details: { action: result.action, runs: result.runs.map(({ handle, name, state, sessionFile, terminal }) => ({ handle, name, state, sessionFile, terminal })) },
				isError: result.isError,
			};
		},
	});
}
