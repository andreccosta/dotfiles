/**
 * Read the last assistant message aloud with macOS `say`.
 *
 * Usage:
 * - `/say`   speak the last assistant message, or stop if already speaking
 */
import { type ChildProcess, spawn } from "node:child_process";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

function lastAssistantText(ctx: ExtensionContext): string | undefined {
	const branch = ctx.sessionManager.getBranch();
	for (let index = branch.length - 1; index >= 0; index--) {
		const entry = branch[index];
		if (entry.type !== "message" || entry.message.role !== "assistant") continue;
		const content = entry.message.content;
		if (typeof content === "string") return content;
		return content
			.filter((part): part is { type: "text"; text: string } => part.type === "text")
			.map((part) => part.text)
			.join("\n");
	}
	return undefined;
}

export default function sayExtension(pi: ExtensionAPI): void {
	if (process.platform !== "darwin") return;

	let speaking: ChildProcess | undefined;

	const stop = () => {
		speaking?.kill();
		speaking = undefined;
	};

	pi.registerCommand("say", {
		description: "Speak the last assistant message (run again to stop)",
		handler: async (_args, ctx) => {
			if (speaking) {
				stop();
				return;
			}
			const text = lastAssistantText(ctx)?.trim();
			if (!text) {
				ctx.ui.notify("No assistant message to speak", "warning");
				return;
			}

			const child = spawn("say", [], { stdio: ["pipe", "ignore", "ignore"] });
			speaking = child;
			const clear = () => {
				if (speaking === child) speaking = undefined;
			};
			child.on("exit", clear);
			child.on("error", (error) => {
				clear();
				ctx.ui.notify(`say failed: ${error.message}`, "error");
			});
			child.stdin.on("error", () => {});
			child.stdin.end(text);
		},
	});

	pi.on("session_shutdown", stop);
}
