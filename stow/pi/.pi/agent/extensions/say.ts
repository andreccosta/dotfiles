/**
 * Read the last assistant message aloud with macOS `say`.
 *
 * Usage:
 * - `/say`       speak the last assistant message, or stop if already speaking
 * - `/say on`    also speak each run's final reply for the rest of the session
 * - `/say off`   stop speaking replies automatically
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
	let autoRead = false;

	const stop = () => {
		speaking?.kill();
		speaking = undefined;
	};

	const speak = (ctx: ExtensionContext) => {
		stop();
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
	};

	const setAutoRead = (ctx: ExtensionContext, enabled: boolean) => {
		autoRead = enabled;
		if (!enabled) stop();
		ctx.ui.setStatus("say", enabled ? "🔊" : undefined);
	};

	pi.registerCommand("say", {
		description: "Speak the last assistant message (run again to stop); on/off toggles auto-read",
		getArgumentCompletions: (prefix) =>
			["on", "off"].filter((value) => value.startsWith(prefix.trim())).map((value) => ({ value, label: value })),
		handler: async (args, ctx) => {
			const mode = args.trim().toLowerCase();
			if (mode === "on" || mode === "off") {
				setAutoRead(ctx, mode === "on");
				return;
			}
			if (mode !== "") {
				ctx.ui.notify(`Unknown argument: ${mode} (expected on or off)`, "warning");
				return;
			}
			if (speaking) {
				stop();
				return;
			}
			speak(ctx);
		},
	});

	pi.on("agent_end", (_event, ctx) => {
		if (autoRead) speak(ctx);
	});

	pi.on("session_shutdown", (_event, ctx) => setAutoRead(ctx, false));
}
