/**
 * Plan/Build mode toggle
 *
 * - Plan mode: only read + bash are available, with bash restricted to read-only commands
 * - Build mode: restores all available tools
 * - Empty editor + Tab toggles between modes
 * - Also exposes /plan, /build, and /toggle-mode commands
 */

import { CustomEditor, type ExtensionAPI, type ExtensionContext } from "@mariozechner/pi-coding-agent";
import { Key, matchesKey } from "@mariozechner/pi-tui";

type Mode = "plan" | "build";

interface ModeState {
	mode: Mode;
}

const PLAN_TOOLS = ["read", "bash", "todo"] as const;

const DESTRUCTIVE_PATTERNS = [
	/\brm\b/i,
	/\brmdir\b/i,
	/\bmv\b/i,
	/\bcp\b/i,
	/\bmkdir\b/i,
	/\btouch\b/i,
	/\bchmod\b/i,
	/\bchown\b/i,
	/\bchgrp\b/i,
	/\bln\b/i,
	/\btee\b/i,
	/\btruncate\b/i,
	/\bdd\b/i,
	/\bshred\b/i,
	/(^|[^<])>(?!>)/,
	/>>/,
	/\bnpm\s+(install|uninstall|update|ci|link|publish)/i,
	/\byarn\s+(add|remove|install|publish)/i,
	/\bpnpm\s+(add|remove|install|publish)/i,
	/\bpip\s+(install|uninstall)/i,
	/\bapt(-get)?\s+(install|remove|purge|update|upgrade)/i,
	/\bbrew\s+(install|uninstall|upgrade)/i,
	/\bgit\s+(add|commit|push|pull|merge|rebase|reset|checkout|branch\s+-[dD]|stash|cherry-pick|revert|tag|init|clone)/i,
	/\bsudo\b/i,
	/\bsu\b/i,
	/\bkill\b/i,
	/\bpkill\b/i,
	/\bkillall\b/i,
];

const SAFE_PATTERNS = [
	/^\s*cat\b/i,
	/^\s*head\b/i,
	/^\s*tail\b/i,
	/^\s*less\b/i,
	/^\s*more\b/i,
	/^\s*grep\b/i,
	/^\s*find\b/i,
	/^\s*ls\b/i,
	/^\s*pwd\b/i,
	/^\s*echo\b/i,
	/^\s*printf\b/i,
	/^\s*wc\b/i,
	/^\s*sort\b/i,
	/^\s*uniq\b/i,
	/^\s*diff\b/i,
	/^\s*file\b/i,
	/^\s*stat\b/i,
	/^\s*du\b/i,
	/^\s*df\b/i,
	/^\s*tree\b/i,
	/^\s*which\b/i,
	/^\s*whereis\b/i,
	/^\s*type\b/i,
	/^\s*env\b/i,
	/^\s*printenv\b/i,
	/^\s*uname\b/i,
	/^\s*whoami\b/i,
	/^\s*id\b/i,
	/^\s*date\b/i,
	/^\s*ps\b/i,
	/^\s*git\s+(status|log|diff|show|branch|remote|config\s+--get)/i,
	/^\s*git\s+ls-/i,
	/^\s*npm\s+(list|ls|view|info|search|outdated|audit)/i,
	/^\s*yarn\s+(list|info|why|audit)/i,
	/^\s*node\s+--version/i,
	/^\s*python\s+--version/i,
	/^\s*curl\b/i,
	/^\s*wget\s+-O\s*-\b/i,
	/^\s*jq\b/i,
	/^\s*sed\s+-n/i,
	/^\s*awk\b/i,
	/^\s*rg\b/i,
	/^\s*fd\b/i,
	/^\s*bat\b/i,
	/^\s*exa\b/i,
];

function isSafeCommand(command: string): boolean {
	const isDestructive = DESTRUCTIVE_PATTERNS.some((pattern) => pattern.test(command));
	const isSafe = SAFE_PATTERNS.some((pattern) => pattern.test(command));
	return !isDestructive && isSafe;
}

class PlanBuildEditor extends CustomEditor {
	constructor(
		tui: ConstructorParameters<typeof CustomEditor>[0],
		theme: ConstructorParameters<typeof CustomEditor>[1],
		keybindings: ConstructorParameters<typeof CustomEditor>[2],
		private readonly toggleMode: () => void,
	) {
		super(tui, theme, keybindings);
	}

	handleInput(data: string): void {
		if (matchesKey(data, Key.tab) && this.getText().trim() === "") {
			this.toggleMode();
			this.tui.requestRender();
			return;
		}

		super.handleInput(data);
	}
}

export default function planBuildModeExtension(pi: ExtensionAPI) {
	let mode: Mode = "build";
	let buildTools: string[] = [];

	function refreshBuildTools(): void {
		buildTools = [...new Set(pi.getAllTools().map((tool) => tool.name))];
	}

	function persistState(): void {
		pi.appendEntry<ModeState>("plan-build-mode", { mode });
	}

	function updateStatus(ctx: ExtensionContext): void {
		const label = mode === "plan" ? ctx.ui.theme.fg("warning", "⏸ plan") : ctx.ui.theme.fg("success", "🔧 build");
		ctx.ui.setStatus("plan-build-mode", label);
	}

	function setMode(ctx: ExtensionContext, nextMode: Mode, notify = true): void {
		refreshBuildTools();
		mode = nextMode;

		if (mode === "plan") {
			const availablePlanTools = PLAN_TOOLS.filter((tool) => buildTools.includes(tool));
			pi.setActiveTools(availablePlanTools);
			if (notify) ctx.ui.notify("Plan mode enabled: read, read-only bash, and todo management only.", "info");
		} else {
			pi.setActiveTools(buildTools);
			if (notify) ctx.ui.notify("Build mode enabled: full tool access restored.", "info");
		}

		updateStatus(ctx);
		persistState();
	}

	function toggleMode(ctx: ExtensionContext, notify = true): void {
		setMode(ctx, mode === "plan" ? "build" : "plan", notify);
	}

	function restoreState(ctx: ExtensionContext): void {
		mode = "build";
		for (const entry of ctx.sessionManager.getBranch()) {
			if (entry.type === "custom" && entry.customType === "plan-build-mode") {
				const data = entry.data as ModeState | undefined;
				if (data?.mode === "plan" || data?.mode === "build") {
					mode = data.mode;
				}
			}
		}
		setMode(ctx, mode, false);
	}

	pi.registerCommand("plan", {
		description: "Switch to plan mode (read-only tools)",
		handler: async (_args, ctx) => setMode(ctx, "plan"),
	});

	pi.registerCommand("build", {
		description: "Switch to build mode (full tool access)",
		handler: async (_args, ctx) => setMode(ctx, "build"),
	});

	pi.registerCommand("toggle-mode", {
		description: "Toggle between plan and build mode",
		handler: async (_args, ctx) => toggleMode(ctx),
	});

	pi.on("session_start", async (_event, ctx) => {
		refreshBuildTools();
		restoreState(ctx);
		if (ctx.hasUI) {
			ctx.ui.setEditorComponent((tui, theme, keybindings) =>
				new PlanBuildEditor(tui, theme, keybindings, () => toggleMode(ctx)),
			);
		}
	});

	pi.on("session_tree", async (_event, ctx) => {
		restoreState(ctx);
	});

	pi.on("tool_call", async (event) => {
		if (mode !== "plan") return;

		if (event.toolName === "bash") {
			const command = typeof event.input.command === "string" ? event.input.command : "";
			if (!isSafeCommand(command)) {
				return {
					block: true,
					reason: `Plan mode only allows read-only bash commands. Blocked: ${command}`,
				};
			}
			return;
		}

		if (event.toolName === "read" || event.toolName === "todo") return;

		return {
			block: true,
			reason: `Plan mode only allows read, read-only bash, and todo management. Blocked tool: ${event.toolName}.`,
		};
	});

	pi.on("context", async (event) => {
		if (mode === "plan") return;

		return {
			messages: event.messages.filter(
				(message) => !("customType" in message && message.customType === "plan-build-mode-context"),
			),
		};
	});

	pi.on("before_agent_start", async () => {
		if (mode !== "plan") return;
		return {
			message: {
				customType: "plan-build-mode-context",
				content: `[PLAN MODE ACTIVE]\nYou are in plan mode.\n- Only use read, read-only bash commands, and the todo tool.\n- Do not modify project files.\n- Todo management is allowed for planning and task tracking.\n- If implementation is required, ask to switch to build mode.\n- Bash is limited to read-only inspection commands.`,
				display: false,
			},
		};
	});
}
