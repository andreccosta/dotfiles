import { spawn, spawnSync } from "node:child_process";
import { createHash, randomUUID } from "node:crypto";
import { existsSync } from "node:fs";
import { basename, resolve } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

type HookPayload = Record<string, unknown>;

type HookCommand = {
	cmd: string;
	prefix: string[];
};

const resolveHookScript = (): string | null => {
	const home = process.env.HOME ?? "";
	const candidates = [
		resolve(home, ".tmux/plugins/tmux-clanker-sidebar/hook.sh"),
		resolve(home, ".config/tmux/plugins/tmux-clanker-sidebar/hook.sh"),
		resolve(process.cwd(), ".tmux/plugins/tmux-clanker-sidebar/hook.sh"),
	];

	for (const candidate of candidates) {
		if (candidate && existsSync(candidate)) return candidate;
	}
	return null;
};

const run = (cmd: string, args: string[]): string => {
	try {
		const child = spawnSync(cmd, args, {
			encoding: "utf8",
			stdio: ["ignore", "pipe", "ignore"],
		});
		if (child.status !== 0) return "";
		return typeof child.stdout === "string" ? child.stdout.trim() : "";
	} catch {
		return "";
	}
};

const resolveBinary = (): string => {
	const fromEnv = process.env.PI_TMUX_CLANKER_SIDEBAR_BIN;
	if (fromEnv) return fromEnv;

	const fromTmux = run("tmux", ["show-options", "-g", "-v", "@clanker_sidebar_bin"]);
	if (fromTmux) return fromTmux;

	const home = process.env.HOME ?? "";
	const candidates = [
		resolve(home, ".config/tmux/plugins/tmux-clanker-sidebar/bin/tmux-clanker-sidebar"),
		resolve(home, ".tmux/plugins/tmux-clanker-sidebar/bin/tmux-clanker-sidebar"),
		"tmux-clanker-sidebar",
	];

	for (const candidate of candidates) {
		if (candidate === "tmux-clanker-sidebar" || existsSync(candidate)) {
			return candidate;
		}
	}

	return "tmux-clanker-sidebar";
};

const getHookCommand = (): HookCommand => {
	const hookScript = resolveHookScript();
	if (hookScript) return { cmd: "bash", prefix: [hookScript, "pi"] };

	const binary = resolveBinary();
	return { cmd: binary, prefix: ["hook", "pi"] };
};

const pickText = (value: unknown): string => {
	if (typeof value === "string") return value;
	if (!Array.isArray(value)) return "";

	const parts: string[] = [];
	for (const item of value) {
		if (!item || typeof item !== "object") continue;
		const type = (item as { type?: unknown }).type;
		const text = (item as { text?: unknown }).text;
		if (type === "text" && typeof text === "string" && text) parts.push(text);
	}
	return parts.join("\n");
};

const stringifyError = (value: unknown): string => {
	if (typeof value === "string") return value;
	if (value instanceof Error) return value.message || value.name;
	if (value && typeof value === "object") {
		const maybeMessage = (value as { message?: unknown }).message;
		if (typeof maybeMessage === "string" && maybeMessage) return maybeMessage;
		try {
			return JSON.stringify(value);
		} catch {
			return String(value);
		}
	}
	return value == null ? "" : String(value);
};

const safeJson = (value: unknown): unknown => {
	try {
		return JSON.parse(JSON.stringify(value));
	} catch {
		return stringifyError(value);
	}
};

const makeEphemeralSessionId = (cwd: string): string => {
	const digest = createHash("sha1")
		.update(`${process.pid}:${cwd}:${Date.now()}:${randomUUID()}`)
		.digest("hex");
	return digest.slice(0, 16);
};

export default function (pi: ExtensionAPI) {
	const hookCommand = getHookCommand();
	let sessionId = "";
	let cwd = process.cwd();
	let lastAssistantMessage = "";
	let lastProviderError = "";
	let runActive = false;

	const hook = (eventName: string, payload: HookPayload) => {
		try {
			const child = spawn(hookCommand.cmd, [...hookCommand.prefix, eventName], {
				stdio: ["pipe", "ignore", "ignore"],
			});
			child.on("error", () => { });
			child.stdin.on("error", () => { });
			child.stdin.end(JSON.stringify(payload));
		} catch {
			// Best-effort bridge only.
		}
	};

	const basePayload = (): HookPayload => ({ cwd, session_id: sessionId });

	pi.on("session_start", async (event, ctx) => {
		cwd = ctx.cwd;
		sessionId = ctx.sessionManager.getSessionFile()
			? basename(ctx.sessionManager.getSessionFile()!).replace(/\.[^.]+$/, "")
			: makeEphemeralSessionId(ctx.cwd);
		lastAssistantMessage = "";
		lastProviderError = "";

		hook("session-start", {
			...basePayload(),
			source: event.reason,
		});
	});

	pi.on("before_agent_start", async (event) => {
		lastProviderError = "";
		runActive = true;
		hook("user-prompt-submit", {
			...basePayload(),
			prompt: event.prompt || "",
		});
	});

	pi.on("message_end", async (event) => {
		if (event.message.role !== "assistant") return;
		const text = pickText((event.message as { content?: unknown }).content).trim();
		if (text) lastAssistantMessage = text;
	});

	pi.on("tool_execution_end", async (event) => {
		hook("activity-log", {
			...basePayload(),
			tool_name: event.toolName,
			tool_input: safeJson(
				(event as { args?: unknown; input?: unknown }).args ??
				(event as { input?: unknown }).input ??
				{},
			),
			tool_response: safeJson(event.result),
		});

		if (event.isError) {
			lastProviderError ||= stringifyError(event.result) || `${event.toolName} failed`;
		}
	});

	pi.on("after_provider_response", async (event) => {
		if (event.status >= 400) {
			lastProviderError = `provider HTTP ${event.status}`;
		}
	});

	pi.on("agent_end", async () => {
		if (lastProviderError) {
			hook("stop-failure", {
				...basePayload(),
				error: lastProviderError,
			});
			runActive = false;
			return;
		}

		hook("stop", {
			...basePayload(),
			last_message: lastAssistantMessage,
		});
		runActive = false;
	});

	pi.on("session_shutdown", async () => {
		if (!runActive) return;
		hook(lastProviderError ? "stop-failure" : "stop", {
			...basePayload(),
			...(lastProviderError
				? { error: lastProviderError }
				: { last_message: lastAssistantMessage }),
		});
		runActive = false;
	});
}
