// Tool-facing operations adapted from gmcabrita/dotfiles' subagent CLI.
import { randomBytes } from "node:crypto";
import { existsSync, mkdirSync, readdirSync, renameSync, writeFileSync } from "node:fs";
import { join, resolve } from "node:path";
import { setTimeout as delay } from "node:timers/promises";
import {
	assistantText, childLiveness, childLivenessAsync, closeRunWindow, effectiveRunStateAsync,
	existingParentGroup, getRunsDir, hasStoredTrustDecision, inboxDir, isValidGroupLabel,
	isValidRunName, launchRun, listRuns, readLatestAssistant, readMetadata, removeRunDir,
	renameRexWindow, updateMetadata, waitForRunShutdown, writeMetadata,
	type RunMetadata,
} from "./shared.ts";

export interface SubagentInput {
	action: "spawn" | "status" | "rename" | "send" | "wait" | "stop" | "list";
	handle?: string;
	name?: string;
	group?: string;
	provider?: string;
	model?: string;
	thinking?: string;
	cwd?: string;
	tools?: string[];
	prompts?: string[];
	files?: string[];
	noExtensions?: boolean;
	noSkills?: boolean;
	noPromptTemplates?: boolean;
	noContextFiles?: boolean;
	message?: string;
	followUp?: boolean;
	timeoutSeconds?: number;
}

export interface ParentContext {
	sessionId: string;
	sessionFile?: string;
	cwd: string;
	provider?: string;
	model?: string;
	thinking?: string;
}

export interface SubagentResult {
	action: SubagentInput["action"];
	runs: RunMetadata[];
	text?: string;
	isError?: boolean;
}

function getRun(handle: string | undefined, parent: ParentContext): RunMetadata {
	if (!handle || !/^[a-z0-9]+$/.test(handle)) throw new Error("A valid subagent handle is required");
	const run = readMetadata(join(getRunsDir(), handle));
	if (!run || run.parentSessionId !== parent.sessionId) throw new Error(`Unknown subagent in this session: ${handle}`);
	return run;
}

function checkedName(name: string | undefined): string {
	const value = name?.trim();
	if (!isValidRunName(value)) throw new Error("Name must be a single line of 1 to 64 characters");
	return value;
}

async function withState(run: RunMetadata): Promise<RunMetadata> {
	return { ...run, state: await effectiveRunStateAsync(run) };
}

function spawn(input: SubagentInput, parent: ParentContext): RunMetadata {
	if (process.env.PI_SUBAGENT_RUN_DIR) throw new Error("Nested subagents are disabled");
	const name = input.name === undefined ? undefined : checkedName(input.name);
	const group = input.group?.trim();
	if (group !== undefined && !isValidGroupLabel(group)) throw new Error("Group must be a single line of 1 to 24 characters");
	const provider = input.provider ?? parent.provider;
	const model = input.model ?? parent.model;
	const thinking = input.thinking ?? parent.thinking ?? "medium";
	if (!provider || !model) throw new Error("Spawn requires a provider and model (or a selected parent model)");
	if (!["off", "minimal", "low", "medium", "high", "xhigh", "max"].includes(thinking)) throw new Error(`Invalid thinking level: ${thinking}`);
	const cwd = resolve(parent.cwd, input.cwd ?? ".");
	if (!existsSync(cwd)) throw new Error(`Working directory not found: ${cwd}`);
	const prompts = input.prompts ?? [];
	const files = (input.files ?? []).map((file) => resolve(parent.cwd, file));
	if (!prompts.some((prompt) => prompt.trim()) && files.length === 0) throw new Error("Spawn requires prompts or files");
	for (const file of files) if (!existsSync(file)) throw new Error(`File not found: ${file}`);
	if (input.tools && (input.tools.length === 0 || input.tools.some((tool) => !tool.trim() || tool.includes(",")))) {
		throw new Error("Tools must contain nonempty individual tool names");
	}
	mkdirSync(getRunsDir(), { recursive: true, mode: 0o700 });
	let handle: string;
	do { handle = randomBytes(3).toString("hex"); } while (existsSync(join(getRunsDir(), handle)));
	const runDir = join(getRunsDir(), handle);
	mkdirSync(inboxDir(runDir), { recursive: true, mode: 0o700 });
	const launchArgs: string[] = [];
	if (input.tools) launchArgs.push("--tools", input.tools.join(","));
	if (input.noExtensions) launchArgs.push("--no-extensions");
	// Always load the control bridge, even if this extension was explicitly loaded
	// in the parent rather than installed in an auto-discovered location.
	launchArgs.push("--extension", join(import.meta.dirname, "index.ts"));
	if (input.noSkills) launchArgs.push("--no-skills");
	if (input.noPromptTemplates) launchArgs.push("--no-prompt-templates");
	if (input.noContextFiles) launchArgs.push("--no-context-files");
	if (!hasStoredTrustDecision(cwd)) launchArgs.push("--no-approve");
	const now = new Date().toISOString();
	const run: RunMetadata = {
		version: 2, handle, name, group: existingParentGroup(parent.sessionId) ?? group,
		parentSessionId: parent.sessionId, parentSessionFile: parent.sessionFile,
		runDir, cwd, provider, model, thinking, launchArgs,
		state: "starting", hasStarted: false, createdAt: now, updatedAt: now,
	};
	writeMetadata(run);
	try {
		const initialArgs = files.map((file) => `@${file}`);
		if (prompts.length) initialArgs.push(`Task:\n${prompts.join("\n\n")}`);
		return launchRun(run, initialArgs);
	} catch (error) {
		removeRunDir(runDir);
		throw error;
	}
}

export async function runSubagent(input: SubagentInput, parent: ParentContext, signal?: AbortSignal): Promise<SubagentResult> {
	signal?.throwIfAborted();
	if (process.env.PI_SUBAGENT_RUN_DIR) throw new Error("Nested subagent management is disabled");
	const result = (runs: RunMetadata[], text?: string, isError?: boolean): SubagentResult => ({ action: input.action, runs, text, isError });
	if (input.action === "spawn") return result([await withState(spawn(input, parent))]);
	if (input.action === "list") return result(await Promise.all(listRuns(parent.sessionId).map(withState)));
	let run = getRun(input.handle, parent);
	switch (input.action) {
		case "status": return result([await withState(run)]);
		case "rename": {
			const updated = updateMetadata(run.runDir, { name: checkedName(input.name) });
			if (!updated) throw new Error(`Could not rename subagent: ${run.handle}`);
			renameRexWindow(updated);
			return result([await withState(updated)]);
		}
		case "send": {
			const message = input.message?.trim();
			if (!message) throw new Error("Send requires a message");
			const liveness = await childLivenessAsync(run.terminal);
			if (liveness !== "running") throw new Error(liveness === "exited" ? `${run.handle} is not running` : "Could not reach Rex");
			const queueDir = inboxDir(run.runDir);
			mkdirSync(queueDir, { recursive: true, mode: 0o700 });
			const target = join(queueDir, `${Date.now()}-${randomBytes(4).toString("hex")}.json`);
			const temporary = `${target}.tmp`;
			writeFileSync(temporary, `${JSON.stringify({ message, delivery: input.followUp ? "followUp" : "auto" })}\n`, { encoding: "utf8", mode: 0o600 });
			renameSync(temporary, target);
			return result([await withState(run)], "Message queued");
		}
		case "wait": {
			const timeout = input.timeoutSeconds ?? 1800;
			if (!Number.isInteger(timeout) || timeout <= 0) throw new Error("timeoutSeconds must be a positive integer");
			const deadline = Date.now() + timeout * 1000;
			while (Date.now() < deadline) {
				signal?.throwIfAborted();
				run = getRun(input.handle, parent);
				const state = await effectiveRunStateAsync(run, signal);
				const pending = existsSync(inboxDir(run.runDir)) && readdirSync(inboxDir(run.runDir)).some((file) => file.endsWith(".json"));
				if (state === "error" || state === "exited") throw new Error(run.error ?? `${run.handle} ${state} before finishing`);
				if (run.hasStarted && state === "idle" && !pending && run.sessionFile) {
					const message = readLatestAssistant(run.sessionFile);
					if (!message) throw new Error(`${run.handle} finished without an assistant response`);
					return result([{ ...run, state }], assistantText(message), message.stopReason === "error" || message.stopReason === "aborted");
				}
				await delay(Math.min(500, Math.max(1, deadline - Date.now())), undefined, { signal });
			}
			throw new Error(`Timed out after ${timeout}s waiting for ${run.handle}`);
		}
		case "stop": {
			const wasRunning = childLiveness(run.terminal) === "running";
			if (!closeRunWindow(run)) throw new Error("Could not close Rex window; run kept");
			if (wasRunning) await waitForRunShutdown(run.runDir);
			if (await childLivenessAsync(run.terminal) !== "exited") throw new Error("Could not confirm shutdown; run kept");
			removeRunDir(run.runDir);
			return result([{ ...run, state: "exited" }], `Stopped ${run.handle}. Transcript kept: ${run.sessionFile ?? "(none)"}`);
		}
		default: throw new Error(`Unknown action: ${input.action}`);
	}
}
