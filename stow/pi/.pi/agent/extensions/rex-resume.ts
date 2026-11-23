// Record the interactive session so a block Rex restores can resume it.
// See ~/.config/rex/resume.zsh.
import { existsSync, mkdirSync, writeFileSync } from "node:fs";
import path from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

// Pi reloads extensions on session switches, so keep the path process-wide,
// and hide it from tool shells so nested agents leave the record alone.
const state = globalThis as { rexResumeFile?: string };
state.rexResumeFile ??= process.env.REX_RESUME_FILE;
delete process.env.REX_RESUME_FILE;

const quote = (s: string) => `'${s.replaceAll("'", `'\\''`)}'`;

export default function (pi: ExtensionAPI) {
	const target = state.rexResumeFile;
	if (!target) return;

	const record = (ctx: ExtensionContext) => {
		if (!ctx.hasUI) return;
		const file = ctx.sessionManager.getSessionFile();
		// Pi writes the session file after the first reply.
		if (!file || !existsSync(file)) return;
		mkdirSync(path.dirname(target), { recursive: true });
		writeFileSync(target, `pi --session ${quote(file)}\n`);
	};

	pi.on("session_start", (_event, ctx) => record(ctx));
	pi.on("agent_end", (_event, ctx) => record(ctx));
}
